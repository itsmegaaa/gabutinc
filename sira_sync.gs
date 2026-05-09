const FIREBASE_PROJECT_ID = 'GANTI_DENGAN_PROJECT_ID';
const SHEET_NAMES = {
  '2024': 'Data 2024',
  '2025': 'Data 2025',
  '2026': 'Data 2026',
};
const COLLECTION_PREFIX = 'laporan_';
const HEADER_ROW = [
  'FIREBASE_ID', 'NAMA DEBITUR', 'NAMA NOTARIS', 'NAMA BANK',
  'PIC BANK', 'NO SURAT ORDER', 'TGL ORDER', 'JENIS', 'RINCIAN ORDER',
  'NO COVERNOTE', 'LIMIT PLAFON', 'NILAI HT', 'BIAYA NOTARIS',
  'TGL PELAKSANAAN', 'BATAS SLA', 'UMUR PEKERJAAN', 'STATUS PEKERJAAN',
  'PROGRES DETAIL', 'TGL BAST', 'NOTES', 'KEKURANGAN', 'PIC INTERNAL',
  'UPDATED BY', 'LAST UPDATE'
];


// 1. ENDPOINT UTAMA — Dipanggil Flutter via HTTP POST
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    if (payload.action === 'sync_from_firebase') {
      const tahun = new Date().getFullYear().toString();
      syncFromFirebase(tahun);
    }
    return _jsonResponse({ status: 'ok', message: 'Sync selesai untuk tahun ' + tahun });
  } catch (err) {
    return _jsonResponse({ status: 'error', message: err.toString() });
  }
}

// 2. FIRESTORE → SPREADSHEET
function syncFromFirebase(tahun) {
  const sheetName = SHEET_NAMES[tahun];
  if (!sheetName) throw new Error('Tahun tidak dikenal: ' + tahun);

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
  }

  const docs = _getAllDocumentsFromFirestore(COLLECTION_PREFIX + tahun);

  sheet.clearContents();
  sheet.getRange(1, 1, 1, HEADER_ROW.length).setValues([HEADER_ROW]);
  sheet.getRange(1, 1, 1, HEADER_ROW.length)
    .setFontWeight('bold')
    .setBackground('#0F172A')
    .setFontColor('#D4AF37');
  sheet.setFrozenRows(1);

  if (docs.length === 0) return;

  const rows = docs.map(doc => {
    const f = doc.fields || {};
    return [
      doc.name.split('/').pop(),
      _getStr(f.namaDebitur),
      _getStr(f.namaNotaris),
      _getStr(f.namaBank),
      _getStr(f.picBank),
      _getStr(f.noSuratOrder),
      _getStr(f.tanggalOrder),
      _getStr(f.jenis),
      _getStr(f.rincianOrder),
      _getStr(f.noCovernote),
      _getStr(f.limitPlafon),
      _getStr(f.nilaiHT),
      _getStr(f.biayaNotaris),
      _getStr(f.tanggalPelaksanaan),
      _getStr(f.batasSla),
      _getStr(f.umurPekerjaan),
      _getStr(f.statusPekerjaan),
      _getStr(f.progresDetail),
      _getStr(f.tanggalBast),
      _getStr(f.notes),
      _getStr(f.kekurangan),
      _getStr(f.picInternal),
      _getStr(f.updatedBy),
      new Date().toLocaleString('id-ID'),
    ];
  });

  sheet.getRange(2, 1, rows.length, HEADER_ROW.length).setValues(rows);
  sheet.hideColumns(1); // Sembunyikan kolom FIREBASE_ID dari user

  _updateSyncMetadata();
  Logger.log('Sync selesai: ' + rows.length + ' dokumen untuk tahun ' + tahun);
}

// 3. SPREADSHEET → FIRESTORE (Trigger onEdit)
function onEdit(e) {
  const sheet = e.source.getActiveSheet();
  const sheetName = sheet.getName();
  const tahun = Object.keys(SHEET_NAMES).find(t => SHEET_NAMES[t] === sheetName);

  if (!tahun) return;
  if (e.range.getRow() <= 1) return; // Abaikan header

  const row = sheet.getRange(e.range.getRow(), 1, 1, HEADER_ROW.length).getValues()[0];
  _syncRowToFirestore(row, tahun);

  // Tandai waktu terakhir edit
  sheet.getRange(e.range.getRow(), HEADER_ROW.length)
    .setValue(new Date().toLocaleString('id-ID'));
}

// 4. JADWAL OTOMATIS — Daftarkan via setupTimeTrigger()
function syncHarian() {
  const tahun = new Date().getFullYear().toString();
  syncFromFirebase(tahun);
}

function setupTimeTrigger() {
  // Hapus semua trigger lama
  ScriptApp.getProjectTriggers().forEach(t => ScriptApp.deleteTrigger(t));

  // Trigger jam 08:00
  ScriptApp.newTrigger('syncHarian')
    .timeBased().atHour(8).everyDays(1).create();

  // Trigger jam 17:00
  ScriptApp.newTrigger('syncHarian')
    .timeBased().atHour(17).everyDays(1).create();

  Logger.log('Time trigger berhasil didaftarkan (08:00 & 17:00)');
}

// HELPER FUNCTIONS
function _getAllDocumentsFromFirestore(collectionId) {
  const token = ScriptApp.getOAuthToken();
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${collectionId}`;
  let allDocs = [];
  let pageToken = null;

  do {
    const url = pageToken ? `${baseUrl}?pageToken=${pageToken}` : baseUrl;
    const response = UrlFetchApp.fetch(url, {
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true,
    });

    const result = JSON.parse(response.getContentText());
    if (result.error) throw new Error('Firestore error: ' + JSON.stringify(result.error));

    if (result.documents) allDocs = allDocs.concat(result.documents);
    pageToken = result.nextPageToken || null;
  } while (pageToken);

  return allDocs;
}

function _syncRowToFirestore(row, tahun) {
  const firebaseId = row[0];
  if (!firebaseId || firebaseId.toString().trim() === '') return;

  const token = ScriptApp.getOAuthToken();
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/${COLLECTION_PREFIX}${tahun}/${firebaseId}`;

  const fields = {
    namaDebitur:        { stringValue: row[1]  || '' },
    namaNotaris:        { stringValue: row[2]  || '' },
    namaBank:           { stringValue: row[3]  || '' },
    picBank:            { stringValue: row[4]  || '' },
    noSuratOrder:       { stringValue: row[5]  || '' },
    tanggalOrder:       { stringValue: row[6]  || '' },
    jenis:              { stringValue: row[7]  || '' },
    rincianOrder:       { stringValue: row[8]  || '' },
    noCovernote:        { stringValue: row[9]  || '' },
    limitPlafon:        { stringValue: row[10] || '0' },
    nilaiHT:            { stringValue: row[11] || '0' },
    biayaNotaris:       { stringValue: row[12] || '0' },
    tanggalPelaksanaan: { stringValue: row[13] || '' },
    batasSla:           { stringValue: row[14] || '' },
    umurPekerjaan:      { stringValue: row[15] || '' },
    statusPekerjaan:    { stringValue: row[16] || '' },
    progresDetail:      { stringValue: row[17] || '' },
    tanggalBast:        { stringValue: row[18] || '' },
    notes:              { stringValue: row[19] || '' },
    kekurangan:         { stringValue: row[20] || '' },
    picInternal:        { stringValue: row[21] || '' },
    updatedBy:          { stringValue: 'GoogleSheets' },
    sudahSyncSheet:     { booleanValue: true },
  };

  UrlFetchApp.fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    payload: JSON.stringify({ fields }),
    muteHttpExceptions: true,
  });
}

function _updateSyncMetadata() {
  const token = ScriptApp.getOAuthToken();
  const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/sync_metadata/status`;
  UrlFetchApp.fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    payload: JSON.stringify({
      fields: {
        lastSyncToSheet: { timestampValue: new Date().toISOString() },
        isSyncing: { booleanValue: false },
      }
    }),
    muteHttpExceptions: true,
  });
}

function _getStr(field) {
  if (!field) return '';
  return field.stringValue || field.integerValue || field.doubleValue || '';
}

function _jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
