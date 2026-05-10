/**
 * SIRA - SINKRONISASI BIDIRECTIONAL FIRESTORE <-> SPREADSHEET (22 KOLOM)
 */

// ============================================================================
// KONSTANTA PENGATURAN AWAL
// ============================================================================
const FIREBASE_PROJECT_ID = 'gabutinc';
const FIREBASE_API_KEY    = 'AIzaSyCfoyVBf7sK2K2NlfoBXd3s4wOqAyW3b8o';
const SPREADSHEET_ID      = SpreadsheetApp.getActiveSpreadsheet().getId();
const SHEET_NAMES         = { '2024': '2024', '2025': '2025', '2026': '2026' };
const COLLECTION_PREFIX   = 'laporan_';

// Mapping 22 Kolom Sesuai Format + 1 Kolom Last Update (Sistem)
const HEADER_ROW = [
  'FIREBASE_ID', 'DEBITUR', 'NAMA NOTARIS', 'KCU/KCP (BANK)', 'PIC (BANK)',
  'NO SURAT ORDER', 'TGL ORDER', 'JENIS', 'RINCIAN ORDER', 'NO COVERNOTE',
  'LIMIT', 'NILAI HT', 'BIAYA', 'TGL PELAKSANAAN', 'BATAS SLA',
  'UMUR PEKERJAAN', 'PROGRES PEKERJAAN', 'PROGRES TERAKHIR', 'TGL BAST', 'PERKASUS (NOTE)',
  'KEKURANGAN BERKAS', 'PIC INTERNAL', 'LAST UPDATE'
];

const BASE_URL = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`;

// ============================================================================
// FUNGSI 4: doPost (Menerima trigger Manual dari Flutter App)
// ============================================================================
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    if (payload.action === 'sync_from_firebase') {
      const tahunAktif = new Date().getFullYear().toString();
      syncFromFirebase(tahunAktif);
      return ContentService.createTextOutput(JSON.stringify({ status: 'ok', message: 'Sync selesai' })).setMimeType(ContentService.MimeType.JSON);
    }
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: 'error', message: err.toString() })).setMimeType(ContentService.MimeType.JSON);
  }
}

// ============================================================================
// FUNGSI 1: syncFromFirebase (Tarik data dari Firestore ke Sheet)
// ============================================================================
function syncFromFirebase(tahun) {
  if (!SHEET_NAMES[tahun]) return;
  const sheetName = SHEET_NAMES[tahun];
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  
  if (!sheet) {
    SpreadsheetApp.getActiveSpreadsheet().insertSheet(sheetName);
    return syncFromFirebase(tahun);
  }

  let allDocuments = [];
  let pageToken = '';
  const collectionPath = `${COLLECTION_PREFIX}${tahun}`;
  
  do {
    let url = `${BASE_URL}/${collectionPath}?key=${FIREBASE_API_KEY}&pageSize=300`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const response = UrlFetchApp.fetch(url, { method: 'get', muteHttpExceptions: true });
    const result = JSON.parse(response.getContentText());

    if (response.getResponseCode() !== 200) {
      Logger.log(`Gagal membaca Firestore: ${result.error.message}`);
      return;
    }
    if (result.documents) allDocuments = allDocuments.concat(result.documents);
    pageToken = result.nextPageToken || '';
  } while (pageToken);

  const rows = allDocuments.map(doc => {
    const fields = doc.fields || {};
    const docId = doc.name.split('/').pop();

    return [
      docId,                                                  // 0. FIREBASE_ID
      _extractValue(fields.namaDebitur),                      // 1. DEBITUR
      _extractValue(fields.namaNotaris),                      // 2. NAMA NOTARIS
      _extractValue(fields.namaBank),                         // 3. KCU/KCP
      _extractValue(fields.picBank),                          // 4. PIC BANK
      _extractValue(fields.noSuratOrder),                     // 5. NO SURAT ORDER
      _formatDateToDMY(_extractValue(fields.tanggalOrder)),   // 6. TGL ORDER
      _extractValue(fields.jenis),                            // 7. JENIS
      _extractValue(fields.rincianOrder),                     // 8. RINCIAN ORDER
      _extractValue(fields.noCovernote),                      // 9. NO COVERNOTE
      _extractValue(fields.limitPlafon) || '0',               // 10. LIMIT
      _extractValue(fields.nilaiHT) || '0',                   // 11. NILAI HT
      _extractValue(fields.biayaNotaris) || '0',              // 12. BIAYA
      _formatDateToDMY(_extractValue(fields.tanggalPelaksanaan)), // 13. TGL PELAKSANAAN
      _formatDateToDMY(_extractValue(fields.batasSla)),       // 14. BATAS SLA
      _extractValue(fields.umurPekerjaan),                    // 15. UMUR PEKERJAAN
      _extractValue(fields.statusPekerjaan),                  // 16. PROGRES PEKERJAAN
      _extractValue(fields.progresDetail),                    // 17. PROGRES TERAKHIR
      _formatDateToDMY(_extractValue(fields.tanggalBast)),    // 18. TGL BAST
      _extractValue(fields.notes),                            // 19. PERKASUS
      _extractValue(fields.kekurangan),                       // 20. KEKURANGAN BERKAS
      _extractValue(fields.picInternal),                      // 21. PIC INTERNAL
      _formatDateToDMY(_extractValue(fields.waktuUpdate))     // 22. LAST UPDATE
    ];
  });

  if (sheet.getLastRow() > 1) {
  // Hanya menghapus data dari baris 2 ke bawah, membiarkan Header & Format tetap ada
  sheet.getRange(2, 1, sheet.getLastRow(), sheet.getLastColumn()).clearContent();
}
  sheet.appendRow(HEADER_ROW);
  sheet.getRange(1, 1, 1, HEADER_ROW.length).setFontWeight('bold');
  sheet.hideColumns(1); // Sembunyikan ID

  if (rows.length > 0) {
    sheet.getRange(2, 1, rows.length, HEADER_ROW.length).setValues(rows);
  }

  // ========================================================================
  // PENTING: Beri "Stempel Lunas" ke Firebase agar Ikon ⚠️ di App Hilang
  // ========================================================================
  allDocuments.forEach(doc => {
    const fields = doc.fields || {};
    
    // Jika data belum di-sync (statusnya false)
    if (!fields.sudahSyncSheet || fields.sudahSyncSheet.booleanValue === false) {
      // Gunakan URL absolut bawaan Firestore API
      const patchUrl = `https://firestore.googleapis.com/v1/${doc.name}?key=${FIREBASE_API_KEY}&updateMask.fieldPaths=sudahSyncSheet`;
      
      const payload = {
        fields: { sudahSyncSheet: { booleanValue: true } }
      };
      
      UrlFetchApp.fetch(patchUrl, {
        method: 'PATCH',
        contentType: 'application/json',
        payload: JSON.stringify(payload),
        muteHttpExceptions: true
      });
    }
  });
  sheet.autoResizeColumns(1, HEADER_ROW.length);
}

// ============================================================================
// FUNGSI 2: syncToFirebase (Dorong data edit dari Sheet ke Firestore)
// ============================================================================
function syncToFirebase(rowData, tahun) {
  const collectionPath = `${COLLECTION_PREFIX}${tahun}`;
  let docId = rowData[0]; 
  
  const isNewDoc = !docId;
  const method = isNewDoc ? 'post' : 'patch';
  let url = `${BASE_URL}/${collectionPath}?key=${FIREBASE_API_KEY}`;
  if (!isNewDoc) url = `${BASE_URL}/${collectionPath}/${docId}?key=${FIREBASE_API_KEY}`;

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

  const response = UrlFetchApp.fetch(url, {
    method: method,
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });
  
  const result = JSON.parse(response.getContentText());
  if (response.getResponseCode() !== 200) return null;
  if (isNewDoc && result.name) return result.name.split('/').pop();
  return docId;
}

// ============================================================================
// FUNGSI 3: onEdit (Trigger otomatis ketika staff mengedit Sheet)
// ============================================================================
function onEdit(e) {
  if (!e || !e.range) return;
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
  if (!rowData[0] && newDocId) sheet.getRange(rowIndex, 1).setValue(newDocId);
  sheet.getRange(rowIndex, HEADER_ROW.length).setValue(new Date());
}

// ============================================================================
// FUNGSI TAMBAHAN: Hapus Data Dari Firebase
// ============================================================================
function deleteFromFirebase(docId, tahun) {
  const collectionPath = `${COLLECTION_PREFIX}${tahun}`;
  const url = `${BASE_URL}/${collectionPath}/${docId}?key=${FIREBASE_API_KEY}`;
  
  UrlFetchApp.fetch(url, {
    method: 'delete',
    muteHttpExceptions: true
  });
}

// ============================================================================
// FUNGSI 5: setupTimeTrigger
// ============================================================================
function setupTimeTrigger() {
  ScriptApp.getProjectTriggers().forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('triggerPagiSore').timeBased().atHour(8).everyDays(1).create();
  ScriptApp.newTrigger('triggerPagiSore').timeBased().atHour(17).everyDays(1).create();
}

function triggerPagiSore() {
  syncFromFirebase(new Date().getFullYear().toString());
  const payload = {
    fields: {
      lastSyncToSheet: { timestampValue: new Date().toISOString() },
      isSyncing: { booleanValue: false },
      trigger: { stringValue: 'terjadwal' }
    }
  };
  UrlFetchApp.fetch(`${BASE_URL}/sync_metadata/status?key=${FIREBASE_API_KEY}&updateMask.fieldPaths=lastSyncToSheet&updateMask.fieldPaths=isSyncing&updateMask.fieldPaths=trigger`, {
    method: 'patch',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });
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
        if (!rowData[0] && newDocId) sheet.getRange(currentRow, 1).setValue(newDocId);
        sheet.getRange(currentRow, HEADER_ROW.length).setValue(new Date());
        successCount++;
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
  if (typeof isoString === 'string' && isoString.includes('-') && isoString.length === 10) {
    const parts = isoString.split('-');
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
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
