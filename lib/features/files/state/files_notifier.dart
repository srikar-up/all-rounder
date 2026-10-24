import 'package:flutter/foundation.dart';
import '../models/file_item.dart';

class FilesNotifier extends ChangeNotifier {
  final List<WorkspaceFileItem> _items = [];
  String _selectedCategory = 'all'; // 'all', 'images', 'html', 'pdf'
  String? _currentFolder;

  FilesNotifier() {
    _initSampleData();
  }

  List<WorkspaceFileItem> get allItems => List.unmodifiable(_items);
  String get selectedCategory => _selectedCategory;
  String? get currentFolder => _currentFolder;

  List<WorkspaceFileItem> get filteredItems {
    return _items.where((item) {
      if (_currentFolder != null && item.folder != _currentFolder) {
        return false;
      }
      if (_selectedCategory == 'all') return true;
      if (_selectedCategory == 'images') return item.type == FileType.image;
      if (_selectedCategory == 'html') return item.type == FileType.html;
      if (_selectedCategory == 'pdf') return item.type == FileType.pdf;
      return true;
    }).toList();
  }

  List<WorkspaceFileItem> get imageFiles =>
      _items.where((item) => item.type == FileType.image).toList();

  List<WorkspaceFileItem> get htmlDocuments =>
      _items.where((item) => item.type == FileType.html).toList();

  List<String> get folders => [
        'Lecture Photos & Diagrams',
        'HTML Magazine Documents',
        'Handouts & PDFs',
        'Daily Notes & Logs',
      ];

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setCurrentFolder(String? folder) {
    _currentFolder = folder;
    notifyListeners();
  }

  void addFile(WorkspaceFileItem item) {
    _items.insert(0, item);
    notifyListeners();
  }

  static const String defaultMagazineTemplate = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>New Magazine Note</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; padding: 20px; }
    .byline { font-size: 12px; color: #6E717A; font-weight: 600; margin-bottom: 16px; }
    .pull-quote { border-left: 4px solid #6246EA; padding-left: 16px; margin: 20px 0; font-size: 17px; font-weight: 700; font-style: italic; color: #6246EA; }
    .image-placeholder { background: #F1EFEA; border: 2px dashed #9CA0AB; border-radius: 16px; padding: 28px; text-align: center; color: #6E717A; font-weight: 700; margin: 20px 0; }
  </style>
</head>
<body>
  <h1>The Architecture of Thought</h1>
  <div class="byline">By Anna Lane · Field Journal Entry</div>
  
  <p>Exploring how personal spatial organisation shapes memory retention and creative synthesis across multimodal documents.</p>
  
  <div class="pull-quote">
    "Structure is not the cage of creativity, but the trellis upon which insight climbs."
  </div>
  
  <p>When notes, magazine zines, and connected alarms operate synchronously on-device, the cognitive load of context switching collapses to zero.</p>
  
  <div class="image-placeholder">
    <img src="attachments/figure1.png" alt="Attach Image or Diagram Here" />
  </div>
</body>
</html>''';

  void updateHtmlDoc(String id, String newContent) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        content: newContent,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  WorkspaceFileItem createHtmlNote({String? title, String? content}) {
    final now = DateTime.now();
    final item = WorkspaceFileItem(
      id: 'html_${now.millisecondsSinceEpoch}',
      name: title ?? 'Untitled Magazine Note.html',
      type: FileType.html,
      folder: 'HTML Magazine Documents',
      size: '4 KB',
      updatedAt: now,
      colorHex: '#6246EA',
      content: content ?? defaultMagazineTemplate,
    );
    addFile(item);
    return item;
  }

  void _initSampleData() {
    final now = DateTime.now();

    _items.addAll([
      // HTML Magazine Document 1
      WorkspaceFileItem(
        id: 'html_1',
        name: 'Quantum Wave Interactive Sheet.html',
        type: FileType.html,
        folder: 'HTML Magazine Documents',
        size: '14 KB',
        updatedAt: now.subtract(const Duration(minutes: 45)),
        colorHex: '#6246EA',
        linkedAlarmOrNote: '08:30 Physics Alarm',
        content: '''<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: 'Plus Jakarta Sans', sans-serif; background: #0F1015; color: #FFFFFF; padding: 20px; margin: 0; }
  .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; background: rgba(253, 190, 88, 0.2); color: #FDBE58; font-size: 11px; font-weight: 800; letter-spacing: 0.5px; }
  h1 { font-size: 22px; font-weight: 800; color: #B4D2FF; margin-top: 10px; line-height: 1.2; }
  p { font-size: 12px; color: rgba(255, 255, 255, 0.8); line-height: 1.5; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 16px; }
  .card { background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 16px; padding: 12px; }
  .card-title { font-size: 10px; color: #FDBE58; font-weight: 700; text-transform: uppercase; }
  .formula { font-family: monospace; font-size: 13px; font-weight: bold; margin-top: 6px; color: #FFFFFF; }
  .card-green .card-title { color: #3CC162; }
  .link-box { margin-top: 16px; padding: 12px; border-radius: 16px; background: rgba(98, 70, 234, 0.25); border: 1px solid #6246EA; display: flex; justify-content: space-between; align-items: center; }
</style>
</head>
<body>
  <span class="badge">PHYS-301 · VISUAL ZINE</span>
  <h1>Schrödinger Wave Equation & Probability Density</h1>
  <p>Magazine-style sandboxed HTML layout with custom CSS cards, dark grid, and offline formulas without cloud dependencies.</p>
  <div class="grid">
    <div class="card">
      <div class="card-title">Time-Dependent</div>
      <div class="formula">iℏ ∂Ψ/∂t = ĤΨ</div>
    </div>
    <div class="card card-green">
      <div class="card-title">Born Rule</div>
      <div class="formula">P(x) = |Ψ(x,t)|²</div>
    </div>
  </div>
  <div class="link-box">
    <div>
      <div style="font-size: 11px; font-weight: bold;">Linked Folder Image</div>
      <div style="font-size: 10px; opacity: 0.75;">/Lectures/Images/Quantum_Well.png</div>
    </div>
  </div>
</body>
</html>''',
      ),

      // HTML Magazine Document 2
      WorkspaceFileItem(
        id: 'html_2',
        name: 'Semester Timetable Poster.html',
        type: FileType.html,
        folder: 'HTML Magazine Documents',
        size: '18 KB',
        updatedAt: now.subtract(const Duration(hours: 3)),
        colorHex: '#FDBE58',
        content: '''<!DOCTYPE html>
<html>
<head>
<style>
  body { font-family: sans-serif; background: #FAF8F5; color: #141416; padding: 20px; }
  h1 { font-size: 20px; font-weight: 800; }
  .slot { background: #FFFFFF; border-radius: 14px; padding: 12px; margin-bottom: 8px; border-left: 5px solid #6246EA; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
</style>
</head>
<body>
  <h1>Autumn 2026 Timetable Poster</h1>
  <div class="slot"><strong>09:00 - 10:30</strong> · Wave Mechanics (Room A5)</div>
  <div class="slot" style="border-left-color: #FDBE58;"><strong>14:00 - 15:30</strong> · Systems Design (Lab B2)</div>
</body>
</html>''',
      ),

      // HTML Document 3
      WorkspaceFileItem(
        id: 'html_3',
        name: 'Periodic Table Reference.html',
        type: FileType.html,
        folder: 'HTML Magazine Documents',
        size: '22 KB',
        updatedAt: now.subtract(const Duration(days: 1)),
        colorHex: '#3CC162',
        content: '<h1>Periodic Table Quick Sheet</h1><p>Offline interactive element grid.</p>',
      ),

      // Standalone Image 1
      WorkspaceFileItem(
        id: 'img_1',
        name: 'Quantum_Potential_Well.png',
        type: FileType.image,
        folder: 'Lecture Photos & Diagrams',
        size: '1.2 MB',
        updatedAt: now.subtract(const Duration(hours: 2)),
        colorHex: '#6246EA',
        linkedAlarmOrNote: '08:30 AM Physics Lecture',
        content: 'Lectures / Lecture Photos · 1420×980 PNG · Linked to 08:30 Alarm',
      ),

      // Standalone Image 2
      WorkspaceFileItem(
        id: 'img_2',
        name: 'Organic_Chem_Distillation.jpg',
        type: FileType.image,
        folder: 'Lecture Photos & Diagrams',
        size: '2.4 MB',
        updatedAt: now.subtract(const Duration(hours: 5)),
        colorHex: '#FF6B57',
        content: 'Lectures / Lab Photos · 2.4 MB JPG · Thursday Slot Prep',
      ),

      // Standalone Image 3
      WorkspaceFileItem(
        id: 'img_3',
        name: 'Whiteboard_Schrodinger_Eq.png',
        type: FileType.image,
        folder: 'Lecture Photos & Diagrams',
        size: '1.8 MB',
        updatedAt: now.subtract(const Duration(days: 1)),
        colorHex: '#FDBE58',
        content: 'Saved directly in /Lectures/Images · Not embedded in MD',
      ),

      // Standalone PDF
      WorkspaceFileItem(
        id: 'pdf_1',
        name: 'Syllabus_Autumn_2026.pdf',
        type: FileType.pdf,
        folder: 'Handouts & PDFs',
        size: '420 KB',
        updatedAt: now.subtract(const Duration(days: 2)),
        colorHex: '#B4D2FF',
        content: 'Standalone PDF stored in /Lectures/Handouts. Linked to Wednesday Timetable.',
      ),
    ]);
  }
}
