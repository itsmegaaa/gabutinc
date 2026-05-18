/**
 * SIRA - SINKRONISASI BIDIRECTIONAL FIRESTORE <-> SPREADSHEET (22 KOLOM)
 */

// ============================================================================
// KONSTANTA PENGATURAN AWAL
// ============================================================================
const FIREBASE_PROJECT_ID = 'gabutinc';
const FIREBASE_API_KEY    = 'AIzaSyCfoyVBf7sK2K2NlfoBXd3s4wOqAyW3b8o';
const SPREADSHEET_ID      = SpreadsheetApp.getActiveSpreadsheet().getId();
const SHEET_NAMES         = { '2023': '2023', '2024': '2024', '2025': '2025', '2026': '2026' };
const COLLECTION_PREFIX   = 'laporan_';

// Mapping 22 Kolom Sesuai Format + 1 Kolom Last Update (Sistem)
const HEADER_ROW = [
  'FIREBASE_ID', 'DEBITUR', 'NAMA NOTARIS', 'KCU/KCP (BANK)', 'PIC (BANK)',
  'NO SURAT ORDER', 'TGL ORDER', 'JENIS', 'RINCIAN ORDER', 'NO COVERNOTE',
  'LIMIT', 'NILAI HT', 'BIAYA', 'TGL PELAKSANAAN', 'BATAS SLA',
  'UMUR PEKERJAAN', 'PROGRES PEKERJAAN', 'PROGRES TERAKHIR', 'TGL BAST', 'PERKASUS (NOTE)',
  'KEKURANGAN BERKAS', 'PIC INTERNAL', 'LAST UPDATE'
];

function getFirebaseConfig_() {
  const props = PropertiesService.getScriptProperties();

  const projectId = props.getProperty('FIREBASE_PROJECT_ID') || FIREBASE_PROJECT_ID;
  const apiKey = props.getProperty('FIREBASE_API_KEY') || FIREBASE_API_KEY;
  const email = props.getProperty('FIREBASE_SYNC_EMAIL');
  const password = props.getProperty('FIREBASE_SYNC_PASSWORD');

  if (!projectId) throw new Error('FIREBASE_PROJECT_ID belum disetel.');
  if (!apiKey) throw new Error('FIREBASE_API_KEY belum disetel.');
  if (!email || !password) {
    throw new Error('FIREBASE_SYNC_EMAIL atau FIREBASE_SYNC_PASSWORD belum disetel di Script Properties.');
  }

  return { projectId, apiKey, email, password };
}

function getFirebaseIdToken_() {
  const cache = CacheService.getScriptCache();
  const cachedToken = cache.get('FIREBASE_ID_TOKEN');
  if (cachedToken) return cachedToken;

  const config = getFirebaseConfig_();
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(config.apiKey)}`;
  const response = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      email: config.email,
      password: config.password,
      returnSecureToken: true
    }),
    muteHttpExceptions: true
  });

  const body = response.getContentText();
  let data = {};
  try {
    data = JSON.parse(body);
  } catch (err) {
    throw new Error(`Response login Firebase tidak valid: ${body}`);
  }

  if (response.getResponseCode() < 200 || response.getResponseCode() >= 300) {
    throw new Error(`Gagal login Firebase Auth: ${body}`);
  }
  if (!data.idToken) {
    throw new Error(`Firebase Auth tidak mengembalikan idToken: ${body}`);
  }

  cache.put('FIREBASE_ID_TOKEN', data.idToken, 3300);
  return data.idToken;
}

function firestoreFetch_(url, options) {
  const finalOptions = options || {};
  finalOptions.muteHttpExceptions = true;
  finalOptions.headers = Object.assign({}, finalOptions.headers || {}, {
    Authorization: `Bearer ${getFirebaseIdToken_()}`
  });

  return UrlFetchApp.fetch(url, finalOptions);
}

function getFirestoreBaseUrl_() {
  const config = getFirebaseConfig_();
  return `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents`;
}

function assertFirestoreResponse_(response, context) {
  const code = response.getResponseCode();
  const body = response.getContentText();

  if (code < 200 || code >= 300) {
    throw new Error(`${context} gagal (${code}): ${body}`);
  }
  if (!body) return {};

  try {
    return JSON.parse(body);
  } catch (err) {
    return {};
  }
}

// ============================================================================
// FUNGSI 4: doGet/doPost (Menerima trigger Manual dari Flutter App)
// ============================================================================
function doGet(e) {
  return handleSyncRequest_(e, 'GET');
}

function doPost(e) {
  return handleSyncRequest_(e, 'POST');
}

function handleSyncRequest_(e, method) {
  let tahunUntukStatus = '';
  try {
    const payload = parseRequestPayload_(e, method);
    Logger.log(`Payload ${method}: ${JSON.stringify(payload)}`);
    if (payload.action !== 'sync_from_firebase') {
      throw new Error('Action tidak dikenali.');
    }

    const tahunAktif = String(payload.tahun || '');
    if (!SHEET_NAMES[tahunAktif]) {
      throw new Error(`Tahun "${tahunAktif}" tidak valid atau belum tersedia di SHEET_NAMES.`);
    }
    tahunUntukStatus = tahunAktif;

    updateSyncStatus({
      tahun: tahunAktif,
      isSyncing: true,
      trigger: 'manual',
      syncError: ''
    });

    Logger.log(`Mulai sync manual tahun ${tahunAktif}`);
    const syncResult = syncFromFirebase(tahunAktif);
    Logger.log(`Selesai sync manual tahun ${tahunAktif}`);

    updateSyncStatus({
      tahun: tahunAktif,
      isSyncing: false,
      trigger: 'manual',
      lastSyncToSheet: new Date(),
      syncError: ''
    });

    return jsonResponse({
      status: 'ok',
      message: `Sync tahun ${tahunAktif} selesai`,
      tahun: tahunAktif,
      rowsWritten: syncResult.rowsWritten,
      documentsRead: syncResult.documentsRead
    });
  } catch (err) {
    try {
      updateSyncStatus({
        tahun: tahunUntukStatus,
        isSyncing: false,
        trigger: 'manual',
        syncError: err.toString()
      });
    } catch (statusErr) {
      Logger.log(`Gagal update status sync: ${statusErr}`);
    }
    return jsonResponse({ status: 'error', message: err.toString() });
  }
}

function parseRequestPayload_(e, method) {
  if (method === 'GET') {
    return e && e.parameter ? e.parameter : {};
  }

  const rawBody = e && e.postData ? e.postData.contents : '{}';
  return JSON.parse(rawBody || '{}');
}

function jsonResponse(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}

function updateSyncStatus(options) {
  const fields = {
    isSyncing: { booleanValue: options.isSyncing === true },
    trigger: { stringValue: String(options.trigger || '') },
    syncError: { stringValue: String(options.syncError || '') }
  };
  const masks = ['isSyncing', 'trigger', 'syncError'];

  if (options.tahun) {
    fields.tahun = { stringValue: String(options.tahun) };
    masks.push('tahun');
  }
  if (options.lastSyncToSheet) {
    fields.lastSyncToSheet = { timestampValue: options.lastSyncToSheet.toISOString() };
    masks.push('lastSyncToSheet');
  }

  const query = masks.map(field => `updateMask.fieldPaths=${encodeURIComponent(field)}`).join('&');
  const baseUrl = getFirestoreBaseUrl_();
  const response = firestoreFetch_(`${baseUrl}/sync_metadata/status?${query}`, {
    method: 'patch',
    contentType: 'application/json',
    payload: JSON.stringify({ fields })
  });
  assertFirestoreResponse_(response, 'Update sync_metadata/status');
}

// ============================================================================
// FUNGSI 1: syncFromFirebase (Tarik data dari Firestore ke Sheet)
// ============================================================================
function syncFromFirebase(tahun) {
  if (!SHEET_NAMES[tahun]) throw new Error(`Tahun "${tahun}" tidak valid atau belum tersedia di SHEET_NAMES.`);

  _setSyncing(true);
  Logger.log(`syncFromFirebase membaca collection ${COLLECTION_PREFIX}${tahun}`);

  let allDocuments = [];
  let sheet = null;

  try {
    const baseUrl = getFirestoreBaseUrl_();
    const sheetName = SHEET_NAMES[tahun];
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    sheet = ss.getSheetByName(sheetName);

    if (!sheet) {
      sheet = ss.insertSheet(sheetName);
    }

    let pageToken = '';
    const collectionPath = `${COLLECTION_PREFIX}${tahun}`;

    do {
      let url = `${baseUrl}/${collectionPath}?pageSize=300`;
      if (pageToken) url += `&pageToken=${pageToken}`;

      const response = firestoreFetch_(url, { method: 'get' });
      const result = JSON.parse(response.getContentText());

      if (response.getResponseCode() !== 200) {
        const message = result.error && result.error.message ? result.error.message : response.getContentText();
        throw new Error(`Gagal membaca Firestore: ${message}`);
      }

      if (result.documents) allDocuments = allDocuments.concat(result.documents);
      pageToken = result.nextPageToken || '';
    } while (pageToken);

    Logger.log(`Jumlah dokumen Firestore tahun ${tahun}: ${allDocuments.length}`);

    const rows = allDocuments.map(doc => {
      const fields = doc.fields || {};
      const docId = doc.name.split('/').pop();

      return [
        docId,
        _extractValue(fields.namaDebitur),
        _extractValue(fields.namaNotaris),
        _extractValue(fields.namaBank),
        _extractValue(fields.picBank),
        _extractValue(fields.noSuratOrder),
        _formatDateToDMY(_extractValue(fields.tanggalOrder)),
        _extractValue(fields.jenis),
        _extractValue(fields.rincianOrder),
        _extractValue(fields.noCovernote),
        _extractValue(fields.limitPlafon) || '0',
        _extractValue(fields.nilaiHT) || '0',
        _extractValue(fields.biayaNotaris) || '0',
        _formatDateToDMY(_extractValue(fields.tanggalPelaksanaan)),
        _formatDateToDMY(_extractValue(fields.batasSla)),
        _extractValue(fields.umurPekerjaan),
        _extractValue(fields.statusPekerjaan),
        _extractValue(fields.progresDetail),
        _formatDateToDMY(_extractValue(fields.tanggalBast)),
        _extractValue(fields.notes),
        _extractValue(fields.kekurangan),
        _extractValue(fields.picInternal),
        _formatDateToDMY(_extractValue(fields.waktuUpdate))
      ];
    });

    const lastRow = sheet.getLastRow();
    const lastColumn = Math.max(sheet.getLastColumn(), HEADER_ROW.length);
    if (lastRow > 1) {
      sheet.getRange(2, 1, lastRow - 1, lastColumn).clearContent();
    }

    sheet.getRange(1, 1, 1, HEADER_ROW.length).setValues([HEADER_ROW]);
    sheet.getRange(1, 1, 1, HEADER_ROW.length).setFontWeight('bold');
    sheet.hideColumns(1);

    if (rows.length > 0) {
      sheet.getRange(2, 1, rows.length, HEADER_ROW.length).setValues(rows);
    }
    Logger.log(`Jumlah baris ditulis ke Sheet "${sheet.getName()}": ${rows.length}`);

    // ========================================================================
    // PENTING: Beri "Stempel Lunas" ke Firebase agar Ikon ⚠️ di App Hilang
    // ========================================================================
    allDocuments.forEach(doc => {
      const fields = doc.fields || {};

      // Jika data belum di-sync (statusnya false)
      if (!fields.sudahSyncSheet || fields.sudahSyncSheet.booleanValue === false) {
        // Gunakan URL absolut bawaan Firestore API
        const docId = doc.name.split('/').pop();
        const patchUrl = `https://firestore.googleapis.com/v1/${doc.name}?updateMask.fieldPaths=sudahSyncSheet`;

        const payload = {
          fields: { sudahSyncSheet: { booleanValue: true } }
        };

        const patchResponse = firestoreFetch_(patchUrl, {
          method: 'PATCH',
          contentType: 'application/json',
          payload: JSON.stringify(payload)
        });
        assertFirestoreResponse_(patchResponse, `Update sudahSyncSheet ${docId}`);
      }
    });

    sheet.autoResizeColumns(1, HEADER_ROW.length);
    return {
      rowsWritten: rows.length,
      documentsRead: allDocuments.length
    };

  } finally {
    _setSyncing(false);
  }
}

// ============================================================================
// FUNGSI 2: syncToFirebase (Dorong data edit dari Sheet ke Firestore)
// ============================================================================
function syncToFirebase(rowData, tahun) {
  const baseUrl = getFirestoreBaseUrl_();
  const collectionPath = `${COLLECTION_PREFIX}${tahun}`;
  let docId = rowData[0]; 
  
  const isNewDoc = !docId;
  const method = isNewDoc ? 'post' : 'patch';
  let url = `${baseUrl}/${collectionPath}`;
  if (!isNewDoc) url = `${baseUrl}/${collectionPath}/${docId}`;

  const payload = {
    fields: {
      tahun: { stringValue: String(tahun) },
      namaDebitur: { stringValue: String(rowData[1] || '').toUpperCase() },
      namaNotaris: { stringValue: String(rowData[2] || '') },
      namaBank: { stringValue: String(rowData[3] || '').toUpperCase() },
      picBank: { stringValue: String(rowData[4] || '') },
      noSuratOrder: { stringValue: String(rowData[5] || '') },
      tanggalOrder: { stringValue: _formatDateToISO(rowData[6]) },
      jenis: { stringValue: String(rowData[7] || '') },
      rincianOrder: { stringValue: String(rowData[8] || '') },
      noCovernote: { stringValue: String(rowData[9] || '').toUpperCase() },
      limitPlafon: { stringValue: String(rowData[10] || '0') },
      nilaiHT: { stringValue: String(rowData[11] || '0') },
      biayaNotaris: { stringValue: String(rowData[12] || '0') },
      tanggalPelaksanaan: { stringValue: _formatDateToISO(rowData[13]) },
      batasSla: { stringValue: _formatDateToISO(rowData[14]) },
      umurPekerjaan: { stringValue: String(rowData[15] || '') },
      statusPekerjaan: { stringValue: String(rowData[16] || '') },
      progresDetail: { stringValue: String(rowData[17] || '') },
      tanggalBast: { stringValue: _formatDateToISO(rowData[18]) },
      notes: { stringValue: String(rowData[19] || '') },
      kekurangan: { stringValue: String(rowData[20] || '').toUpperCase() },
      picInternal: { stringValue: String(rowData[21] || '') },
      
      updatedBy: { stringValue: 'GoogleSheets' },
      waktuUpdate: { timestampValue: new Date().toISOString() },
      sudahSyncSheet: { booleanValue: true }
    }
  };

  const response = firestoreFetch_(url, {
    method: method,
    contentType: 'application/json',
    payload: JSON.stringify(payload)
  });
  
  const result = JSON.parse(response.getContentText());
  if (response.getResponseCode() !== 200) return null;
  if (isNewDoc && result.name) return result.name.split('/').pop();
  return docId;
}

// ============================================================================
// HELPER GUARD (tambahkan di atas, sebelum onEdit)
// ============================================================================
function _setSyncing(val) {
  PropertiesService.getScriptProperties().setProperty('IS_SYNCING', val ? 'true' : 'false');
}

function _isSyncing() {
  return PropertiesService.getScriptProperties().getProperty('IS_SYNCING') === 'true';
}


// ============================================================================
// FUNGSI 3: onEdit (Trigger otomatis ketika staff mengedit Sheet)
// ============================================================================
function onEdit(e) {
  if (!e || !e.range) return;
  if (_isSyncing()) return;

  const sheet = e.source.getActiveSheet();
  const tahun = Object.keys(SHEET_NAMES).find(t => SHEET_NAMES[t] === sheet.getName());
  
  if (!tahun || e.range.getRow() <= 1) return;
  const rowIndex = e.range.getRow();
  const rowData = sheet.getRange(rowIndex, 1, 1, HEADER_ROW.length).getValues()[0];
  
  // LOGIKA PENGHAPUSAN: Jika FIREBASE_ID ada, TAPI kolom Nama Debitur kosong
  if (rowData[0] && String(rowData[1]).trim() === '') {
    deleteFromFirebase(rowData[0], tahun);      // 1. Hapus dokumen di Firebase
    sheet.getRange(rowIndex, 1).clearContent(); // 2. Bersihkan sisa FIREBASE_ID yang tersembunyi
    return; // Hentikan script agar data kosong tidak dikirim ke Firebase
  }

  // Cegah pembuatan dokumen baru jika pengguna hanya mengetik di sel kosong tanpa mengisi nama debitur
  if (!rowData[0] && String(rowData[1]).trim() === '') return;
  
  // Jika normal (ada nama debitur), kirim data
  const newDocId = syncToFirebase(rowData, tahun);

  if (newDocId === null) {
    e.source.toast(
      `⚠️ Sync ke Firebase gagal di baris ${rowIndex}. Data tidak ditulis ke Sheet untuk mencegah duplikat.`,
      'SIRA SYNC',
      8
    );
    return;
  }

  if (!rowData[0] && newDocId) sheet.getRange(rowIndex, 1).setValue(newDocId);
  sheet.getRange(rowIndex, HEADER_ROW.length).setValue(new Date());
}

// ============================================================================
// FUNGSI TAMBAHAN: Hapus Data Dari Firebase
// ============================================================================
function deleteFromFirebase(docId, tahun) {
  const baseUrl = getFirestoreBaseUrl_();
  const collectionPath = `${COLLECTION_PREFIX}${tahun}`;
  const url = `${baseUrl}/${collectionPath}/${docId}`;
  
  const response = firestoreFetch_(url, { method: 'delete' });
  assertFirestoreResponse_(response, `Delete Firestore ${docId}`);
}

// ============================================================================
// FUNGSI 5: setupTimeTrigger
// ============================================================================
function setupTimeTrigger() {
  ScriptApp.getProjectTriggers().forEach(t => {
    if (t.getHandlerFunction() === 'triggerPagiSore') {
      ScriptApp.deleteTrigger(t);
    }
  });

  ScriptApp.newTrigger('triggerPagiSore').timeBased().atHour(8).everyDays(1).create();
  ScriptApp.newTrigger('triggerPagiSore').timeBased().atHour(17).everyDays(1).create();
}

function triggerPagiSore() {
  const baseUrl = getFirestoreBaseUrl_();
  syncFromFirebase(new Date().getFullYear().toString());
  const payload = {
    fields: {
      lastSyncToSheet: { timestampValue: new Date().toISOString() },
      isSyncing: { booleanValue: false },
      trigger: { stringValue: 'terjadwal' }
    }
  };

  const response = firestoreFetch_(`${baseUrl}/sync_metadata/status?updateMask.fieldPaths=lastSyncToSheet&updateMask.fieldPaths=isSyncing&updateMask.fieldPaths=trigger`, {
    method: 'patch',
    contentType: 'application/json',
    payload: JSON.stringify(payload)
  });
  assertFirestoreResponse_(response, 'Update sync_metadata/status triggerPagiSore');
}

// ============================================================================
// FUNGSI 6: CUSTOM MENU SIRA TOOLS (Sinkronisasi Masal AUTO-ESTAFET)
// ============================================================================

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('🚀 SIRA TOOLS')
    .addItem('Kirim Semua Data (AUTO)', 'syncAllToFirebase')
    .addToUi();
}

// 1. Fungsi Pemicu Awal
function syncAllToFirebase() {
  const ui = SpreadsheetApp.getUi();
  const sheet = SpreadsheetApp.getActiveSheet();
  const sheetName = sheet.getName();
  const tahun = Object.keys(SHEET_NAMES).find(t => SHEET_NAMES[t] === sheetName);

  if (!tahun) {
    ui.alert('⚠️ Salah Sheet', 'Harap buka tab Sheet tahunan (contoh: 2026 atau 2025).', ui.ButtonSet.OK);
    return;
  }

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return;

  const response = ui.alert(
    '🚀 Auto-Sync Dimulai',
    `Sistem akan memproses ${lastRow - 1} data secara otomatis.\n\nSistem dibekali AI Estafet: Jika waktu habis di tengah jalan, sistem akan menyimpan memori dan otomatis jalan lagi 1 menit kemudian tanpa perlu Anda klik apa-apa.\n\nAnda boleh menutup Google Sheets ini. Lanjutkan?`,
    ui.ButtonSet.YES_NO
  );

  if (response !== ui.Button.YES) return;

  // Bersihkan sisa trigger lama jika ada
  clearAutoSyncTriggers();

  // Simpan memori awal ke brankas Google
  const props = PropertiesService.getScriptProperties();
  props.setProperty('AUTO_SYNC_SHEET', sheetName);
  props.setProperty('AUTO_SYNC_ROW', '2'); // Mulai dari baris 2
  props.setProperty('AUTO_SYNC_SUCCESS', '0');
  props.setProperty('AUTO_SYNC_ERROR', '0');

  // Munculkan notifikasi kecil di pojok kanan bawah
  SpreadsheetApp.getActiveSpreadsheet().toast('Mesin estafet dinyalakan... Silakan tinggalkan laptop Anda.', 'SIRA AUTO', -1);

  // Panggil si pekerja keras
  autoSyncWorker();
}

// 2. Fungsi Pekerja Keras (Bisa memanggil dirinya sendiri)
function autoSyncWorker() {
  const startTime = Date.now();
  const MAX_TIME = 4.5 * 60 * 1000; // Batas aman: 4,5 Menit (Google limit: 6 menit)

  const props = PropertiesService.getScriptProperties();
  const sheetName = props.getProperty('AUTO_SYNC_SHEET');
  if (!sheetName) return; // Tidak ada tugas

  // Menggunakan SPREADSHEET_ID global yang sudah kita set di paling atas skrip
  const ss = SpreadsheetApp.openById(SPREADSHEET_ID); 
  const sheet = ss.getSheetByName(sheetName);
  const tahun = Object.keys(SHEET_NAMES).find(t => SHEET_NAMES[t] === sheetName);

  let currentRow = parseInt(props.getProperty('AUTO_SYNC_ROW'));
  let successCount = parseInt(props.getProperty('AUTO_SYNC_SUCCESS'));
  let errorCount = parseInt(props.getProperty('AUTO_SYNC_ERROR'));
  const lastRow = sheet.getLastRow();

  // Looping baris demi baris
  while (currentRow <= lastRow) {
    // CEK WAKTU: Jika sudah lewat 4,5 menit, oper tongkat estafet!
    if (Date.now() - startTime > MAX_TIME) {
      // Simpan jejak baris terakhir
      props.setProperty('AUTO_SYNC_ROW', currentRow.toString());
      props.setProperty('AUTO_SYNC_SUCCESS', successCount.toString());
      props.setProperty('AUTO_SYNC_ERROR', errorCount.toString());

      // Buat pemicu (trigger) untuk menjalankan fungsi ini lagi 1 menit dari sekarang
      ScriptApp.newTrigger('autoSyncWorker')
        .timeBased()
        .after(1000 * 60) // 1 menit jeda napas
        .create();

      console.log(`Batas waktu hampir habis. Istirahat di baris ${currentRow}. Lanjut 1 menit lagi.`);
      return; // Hentikan eksekusi ini
    }

    // Eksekusi Data Normal
    const rowData = sheet.getRange(currentRow, 1, 1, HEADER_ROW.length).getValues()[0];
    if (rowData[1]) { // Jika nama debitur ada isinya
      try {
        const newDocId = syncToFirebase(rowData, tahun);

        if (newDocId === null) {
          errorCount++;
        } else {
          if (!rowData[0] && newDocId) sheet.getRange(currentRow, 1).setValue(newDocId);
          sheet.getRange(currentRow, HEADER_ROW.length).setValue(new Date());
          successCount++;
        }
      } catch (e) {
        errorCount++;
      }
    }
    currentRow++;
  }

  // ==========================================
  // JIKA SUDAH SELESAI SEMUA BARIS (FINISH)
  // ==========================================
  clearAutoSyncTriggers(); // Matikan alarm
  props.deleteProperty('AUTO_SYNC_SHEET'); // Hapus memori
  props.deleteProperty('AUTO_SYNC_ROW');
  
  ss.toast(`✅ TUNTAS! Berhasil: ${successCount} data. Gagal: ${errorCount} data.`, 'SIRA AUTO-SYNC', 15);
}

// 3. Fungsi Pembersih Alarm
function clearAutoSyncTriggers() {
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(t => {
    if (t.getHandlerFunction() === 'autoSyncWorker') {
      ScriptApp.deleteTrigger(t);
    }
  });
}

// ============================================================================
// HELPER FORMATTER
// ============================================================================
function _extractValue(fieldObj) {
  if (!fieldObj) return '';
  if (fieldObj.stringValue !== undefined) return fieldObj.stringValue;
  if (fieldObj.integerValue !== undefined) return fieldObj.integerValue;
  if (fieldObj.booleanValue !== undefined) return fieldObj.booleanValue;
  if (fieldObj.timestampValue !== undefined) return fieldObj.timestampValue;
  return '';
}

function _formatDateToDMY(isoString) {
  if (!isoString) return '';

  if (isoString instanceof Date && !isNaN(isoString.getTime())) {
    const day = String(isoString.getDate()).padStart(2, '0');
    const month = String(isoString.getMonth() + 1).padStart(2, '0');
    const year = isoString.getFullYear();
    return `${day}/${month}/${year}`;
  }

  const strDate = String(isoString).trim();

  if (/^\d{4}-\d{2}-\d{2}$/.test(strDate)) {
    const parts = strDate.split('-');
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
  }

  const parsedDate = new Date(strDate);
  if (!isNaN(parsedDate.getTime())) {
    const day = String(parsedDate.getDate()).padStart(2, '0');
    const month = String(parsedDate.getMonth() + 1).padStart(2, '0');
    const year = parsedDate.getFullYear();
    return `${day}/${month}/${year}`;
  }

  return isoString;
}

function _formatDateToISO(sheetDate) {
  if (!sheetDate) return '';
  if (sheetDate instanceof Date) {
    return `${sheetDate.getFullYear()}-${String(sheetDate.getMonth() + 1).padStart(2, '0')}-${String(sheetDate.getDate()).padStart(2, '0')}`;
  }

  const strDate = String(sheetDate);
  if (strDate.includes('/')) {
    const parts = strDate.split('/');
    if (parts.length === 3) return `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`;
  }

  return strDate;
}
