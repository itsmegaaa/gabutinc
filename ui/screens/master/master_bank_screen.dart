import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class MasterBankScreen extends StatelessWidget {
  const MasterBankScreen({Key? key}) : super(key: key);

  // Fungsi untuk menampilkan Dialog Tambah/Edit Bank
  void _tampilDialogBank(BuildContext context, {DocumentSnapshot? doc}) {
    final bankCtrl =
        TextEditingController(text: doc != null ? doc['namaBank'] : '');
    final picCtrl =
        TextEditingController(text: doc != null ? doc['namaPic'] : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc == null ? 'TAMBAH BANK' : 'EDIT BANK',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bankCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama KCU/KCP Bank',
                hintText: 'Contoh: KCP GARUT CILEDUG',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: picCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama PIC Bank',
                hintText: 'Masukkan nama PIC',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.navyColor),
            onPressed: () {
              if (bankCtrl.text.trim().isEmpty) return;

              final data = {
                'namaBank': bankCtrl.text.trim(),
                'namaPic': picCtrl.text.trim(),
                'waktuUpdate': FieldValue.serverTimestamp(),
              };

              if (doc == null) {
                FirebaseFirestore.instance.collection('master_bank').add(data);
              } else {
                doc.reference.update(data);
              }
              Navigator.pop(ctx);
            },
            child: const Text('SIMPAN',
                style: TextStyle(color: AppConstants.goldColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MASTER DATA BANK'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppConstants.navyColor,
        onPressed: () => _tampilDialogBank(context),
        child: const Icon(Icons.add, color: AppConstants.goldColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('master_bank')
            .orderBy('namaBank')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Terjadi kesalahan'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppConstants.goldColor));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
                child: Text('Belum ada data bank. Klik + untuk menambah.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [AppConstants.primaryShadow],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.navyColor,
                    child: Icon(Icons.account_balance,
                        color: AppConstants.goldColor, size: 20),
                  ),
                  title: Text(
                    doc['namaBank'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    'PIC: ${doc['namaPic'].toString().isEmpty ? "-" : doc['namaPic']}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _tampilDialogBank(context, doc: doc),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Data?'),
                              content: const Text(
                                  'Data bank ini akan dihapus permanen.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('BATAL')),
                                TextButton(
                                    onPressed: () {
                                      doc.reference.delete();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('HAPUS',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
