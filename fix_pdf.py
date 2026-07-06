import re

with open('lib/features/timetable/domain/usecases/pdf_export_usecase.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'package:pdf/widgets.dart' as pw;", "import 'package:pdf/widgets.dart' as pw;\n\nconst double _highResFactor = 3.0;")

# Find `generateTimetablePdf`
gen_pdf_idx = content.find("Future<Uint8List> generateTimetablePdf")

if gen_pdf_idx != -1:
    before = content[:gen_pdf_idx]
    after = content[gen_pdf_idx:]

    # 1. Update format
    after = after.replace(
        "    PdfPageFormat format = settings.exportOrientation == 'Portrait'\n        ? baseFormat.portrait\n        : baseFormat.landscape;",
        "    PdfPageFormat format = settings.exportOrientation == 'Portrait'\n        ? baseFormat.portrait\n        : baseFormat.landscape;\n\n    final PdfPageFormat highResFormat = PdfPageFormat(\n      format.width * _highResFactor,\n      format.height * _highResFactor,\n      marginTop: 20 * _highResFactor,\n      marginBottom: 20 * _highResFactor,\n      marginLeft: 20 * _highResFactor,\n      marginRight: 20 * _highResFactor,\n    );",
        1
    )

    # 2. Update doc.addPage arguments
    after = after.replace("pageFormat: format,", "pageFormat: highResFormat,", 1)
    after = after.replace("margin: const pw.EdgeInsets.all(20),", "margin: pw.EdgeInsets.all(20 * _highResFactor),", 1)
    after = after.replace("pw.SizedBox(height: 15),", "pw.SizedBox(height: 15 * _highResFactor),", 1)
    after = after.replace("format.availableHeight - 120", "highResFormat.availableHeight - (120 * _highResFactor)", 1)

    # 3. Update Font sizes
    after = after.replace("fontSize: 14,", "fontSize: 14 * _highResFactor,", 1)
    after = after.replace("fontSize: 18,", "fontSize: 18 * _highResFactor,", 1)
    after = after.replace("fontSize: 16,", "fontSize: 16 * _highResFactor,", 1)
    after = after.replace("fontSize: 12,", "fontSize: 12 * _highResFactor,", 1) # Header
    after = after.replace("fontSize: 12,", "fontSize: 12 * _highResFactor,", 1) # Header subtitle
    after = after.replace("pw.SizedBox(height: 4),", "pw.SizedBox(height: 4 * _highResFactor),", 1)
    after = after.replace("pw.SizedBox(height: 4),", "pw.SizedBox(height: 4 * _highResFactor),", 1)

    after = after.replace("padding: const pw.EdgeInsets.only(top: 10),", "padding: pw.EdgeInsets.only(top: 10 * _highResFactor),", 1)
    after = after.replace("fontSize: 12,", "fontSize: 12 * _highResFactor,", 1) # Footer

    # 4. Borders and padding
    after = after.replace("width: 0.5)", "width: 0.5 * _highResFactor)")
    after = after.replace("width: 0.5,", "width: 0.5 * _highResFactor,")
    after = after.replace("const pw.BorderSide", "pw.BorderSide")
    after = after.replace("padding: const pw.EdgeInsets.all(1),", "padding: pw.EdgeInsets.all(1 * _highResFactor),")
    after = after.replace("padding: const pw.EdgeInsets.all(4),", "padding: pw.EdgeInsets.all(4 * _highResFactor),")

    content = before + after

with open('lib/features/timetable/domain/usecases/pdf_export_usecase.dart', 'w') as f:
    f.write(content)
