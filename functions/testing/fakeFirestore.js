'use strict';

/**
 * Firestore em memória para testes de fluxo das Functions (sem emulador).
 * Cobre só o subconjunto da API usado em index.js.
 */

class Timestamp {
  constructor(ms) { this._ms = ms; }
  static now() { return new Timestamp(Date.now()); }
  static fromDate(d) { return new Timestamp(d.getTime()); }
  static fromMillis(ms) { return new Timestamp(ms); }
  toDate() { return new Date(this._ms); }
  toMillis() { return this._ms; }
  valueOf() { return this._ms; }
}

const FieldValue = {
  serverTimestamp: () => ({ __fv: 'ts' }),
  increment: (n) => ({ __fv: 'inc', n }),
  delete: () => ({ __fv: 'del' }),
  arrayUnion: (...v) => ({ __fv: 'union', v }),
};

function clone(v) {
  if (v instanceof Timestamp) return new Timestamp(v._ms);
  if (v instanceof Date) return new Date(v.getTime());
  if (Array.isArray(v)) return v.map(clone);
  if (v && typeof v === 'object') {
    const o = {};
    for (const [k, x] of Object.entries(v)) o[k] = clone(x);
    return o;
  }
  return v;
}

function applyFields(target, data) {
  for (const [k, v] of Object.entries(data)) {
    if (v && v.__fv === 'ts') target[k] = Timestamp.now();
    else if (v && v.__fv === 'inc') target[k] = Number(target[k] || 0) + v.n;
    else if (v && v.__fv === 'del') delete target[k];
    else if (v && v.__fv === 'union') {
      const cur = Array.isArray(target[k]) ? target[k] : [];
      target[k] = [...cur, ...v.v.filter((x) => !cur.includes(x))];
    } else target[k] = clone(v);
  }
  return target;
}

function cmp(a, b) {
  const x = a instanceof Timestamp || a instanceof Date ? a.valueOf() : a;
  const y = b instanceof Timestamp || b instanceof Date ? b.valueOf() : b;
  return x < y ? -1 : (x > y ? 1 : 0);
}

let autoId = 0;

class FakeDb {
  constructor() { this.store = new Map(); }

  collection(name) { return new CollectionRef(this, name); }
  doc(path) {
    const parts = path.split('/');
    return new DocRef(this, parts.slice(0, -1).join('/'), parts[parts.length - 1]);
  }
  batch() { return new Batch(this); }

  async runTransaction(fn) {
    const tx = new Transaction(this);
    const out = await fn(tx);
    tx.commit();
    return out;
  }

  seed(path, data) { this.store.set(path, clone(data)); }
  read(path) { const d = this.store.get(path); return d ? clone(d) : undefined; }

  _write(path, data, { merge = false, update = false } = {}) {
    const cur = this.store.get(path);
    if (update && !cur) {
      const err = new Error(`NOT_FOUND: ${path}`);
      err.code = 5;
      throw err;
    }
    const base = merge || update ? clone(cur || {}) : {};
    this.store.set(path, applyFields(base, data));
  }
}

class DocRef {
  constructor(db, colPath, id) {
    this.db = db;
    this.id = id;
    this.path = `${colPath}/${id}`;
    this.parentPath = colPath;
  }
  collection(name) { return new CollectionRef(this.db, `${this.path}/${name}`); }
  async get() { return snapOf(this); }
  async set(data, opts) { this.db._write(this.path, data, { merge: Boolean(opts && opts.merge) }); }
  async update(data) { this.db._write(this.path, data, { update: true }); }
  async delete() { this.db.store.delete(this.path); }
}

function snapOf(ref) {
  const data = ref.db.read(ref.path);
  return { id: ref.id, ref, exists: data !== undefined, data: () => data };
}

class Query {
  constructor(db, colPath, filters = [], lim = null, order = null) {
    this.db = db;
    this.colPath = colPath;
    this.filters = filters;
    this.lim = lim;
    this.order = order;
  }
  where(field, op, value) {
    return new Query(this.db, this.colPath, [...this.filters, { field, op, value }], this.lim, this.order);
  }
  orderBy(field, dir = 'asc') { return new Query(this.db, this.colPath, this.filters, this.lim, { field, dir }); }
  limit(n) { return new Query(this.db, this.colPath, this.filters, n, this.order); }
  async get() {
    const prefix = `${this.colPath}/`;
    let docs = [];
    for (const path of this.db.store.keys()) {
      if (!path.startsWith(prefix) || path.slice(prefix.length).includes('/')) continue;
      const data = this.db.read(path);
      const ok = this.filters.every(({ field, op, value }) => {
        const v = data[field];
        if (v === undefined) return false;
        switch (op) {
          case '==': return cmp(v, value) === 0;
          case '<=': return cmp(v, value) <= 0;
          case '<': return cmp(v, value) < 0;
          case '>=': return cmp(v, value) >= 0;
          case '>': return cmp(v, value) > 0;
          case 'in': return value.includes(v);
          case 'array-contains': return Array.isArray(v) && v.includes(value);
          default: throw new Error(`op ${op} não suportado`);
        }
      });
      if (ok) docs.push(snapOf(new DocRef(this.db, this.colPath, path.slice(prefix.length))));
    }
    if (this.order) {
      const { field, dir } = this.order;
      docs.sort((a, b) => cmp(a.data()[field], b.data()[field]) * (dir === 'desc' ? -1 : 1));
    }
    if (this.lim != null) docs = docs.slice(0, this.lim);
    return { docs, empty: docs.length === 0, size: docs.length, forEach: (f) => docs.forEach(f) };
  }
}

class CollectionRef extends Query {
  constructor(db, path) { super(db, path); this.path = path; }
  doc(id) { return new DocRef(this.db, this.path, id || `auto${++autoId}`); }
  async add(data) { const ref = this.doc(); await ref.set(data); return ref; }
}

class Transaction {
  constructor(db) { this.db = db; this.writes = []; }
  async get(refOrQuery) {
    if (refOrQuery instanceof DocRef) return snapOf(refOrQuery);
    return refOrQuery.get();
  }
  set(ref, data, opts) { this.writes.push(() => this.db._write(ref.path, data, { merge: Boolean(opts && opts.merge) })); return this; }
  update(ref, data) { this.writes.push(() => this.db._write(ref.path, data, { update: true })); return this; }
  delete(ref) { this.writes.push(() => this.db.store.delete(ref.path)); return this; }
  commit() { this.writes.forEach((w) => w()); }
}

class Batch extends Transaction {
  async commit() { super.commit(); }
}

function createFakeAdmin() {
  const db = new FakeDb();
  const firestore = () => db;
  firestore.FieldValue = FieldValue;
  firestore.Timestamp = Timestamp;
  return {
    db,
    admin: {
      initializeApp: () => {},
      firestore,
      auth: () => ({ deleteUser: async () => {} }),
      messaging: () => ({ send: async () => 'ok' }),
    },
  };
}

module.exports = { createFakeAdmin, Timestamp };
