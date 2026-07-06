with open('lib/features/timetable/domain/usecases/pdf_export_usecase.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'package:pdf/widgets.dart' as pw;\n\nconst double _highResFactor = 3.0;", "import 'package:pdf/widgets.dart' as pw;")

import_end_idx = content.rfind("import '")
next_newline_idx = content.find("\n", import_end_idx)
before = content[:next_newline_idx+1]
after = content[next_newline_idx+1:]
content = before + "\nconst double _highResFactor = 3.0;\n" + after

with open('lib/features/timetable/domain/usecases/pdf_export_usecase.dart', 'w') as f:
    f.write(content)
