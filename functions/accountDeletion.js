'use strict';

const ANONYMOUS_NAME = 'Usuário removido';

/** Coleções que a lei/obrigação operacional exige manter (não apagar). */
const RETAIN_COLLECTIONS = [
  'orders',
  'payments',
  'transactions',
  'financialAudits',
  'contracts',
  'auditLogs',
  'legalRetention',
  'xpEvents',
  'wallets',
];

/** Dados sem obrigação de guarda — podem ser apagados no pedido de exclusão. */
const DELETE_ON_REQUEST = [
  'favorites',
  'notifications',
];

function mustRetainCollection(name) {
  return RETAIN_COLLECTIONS.includes(name);
}

function mayDeleteCollection(name) {
  return DELETE_ON_REQUEST.includes(name);
}

function userAnonymizedProfile() {
  return {
    name: ANONYMOUS_NAME,
    email: '',
    photoUrl: null,
    city: '',
    state: '',
    address: null,
    phone: null,
    cpf: null,
    fcmToken: null,
    lat: null,
    lng: null,
    status: 'deleted',
    anonymized: true,
    plan: 'free',
    verified: false,
  };
}

function providerAnonymizedProfile() {
  return {
    name: ANONYMOUS_NAME,
    photoUrl: null,
    documentUrl: null,
    selfieUrl: null,
    active: false,
    anonymized: true,
  };
}

function companyAnonymizedProfile() {
  return {
    name: ANONYMOUS_NAME,
    phone: null,
    email: '',
    address: null,
    logoUrl: null,
    active: false,
    anonymized: true,
  };
}

function retentionYears() {
  return 5;
}

function retentionUntil(fromDate) {
  const d = fromDate instanceof Date ? new Date(fromDate.getTime()) : new Date();
  d.setUTCFullYear(d.getUTCFullYear() + retentionYears());
  return d;
}

function adminMayHardDeleteUserDoc() {
  return false;
}

module.exports = {
  ANONYMOUS_NAME,
  RETAIN_COLLECTIONS,
  DELETE_ON_REQUEST,
  mustRetainCollection,
  mayDeleteCollection,
  userAnonymizedProfile,
  providerAnonymizedProfile,
  companyAnonymizedProfile,
  retentionYears,
  retentionUntil,
  adminMayHardDeleteUserDoc,
};
