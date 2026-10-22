import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generate a user-triggered read-only report locally on the phone.
/// Does not send business data to an external PDF conversion server.
/// Unicode font may be fetched/cached by printing on first use.
class OwnerAiExport {
  const OwnerAiExport._();

  static List<List<String>> rows(Map<String,dynamic>? report) {
    final result=<List<String>>[];
    if(report==null)return result;
    final header=(report['columns'] as List? ?? [])
      .take(8).map((col)=>col is Map
        ?(col['label']??'').toString():col.toString()).toList();
    if(header.isEmpty)return result;
    result.add(header);
    for(final row in (report['rows'] as List? ?? []).take(80)){
      if(row is! List)continue;
      result.add(List.generate(header.length,
        (index)=>index<row.length ? row[index].toString() : ''));
    }
    return result;
  }

  static List<List<String>> chartPoints(Map<String,dynamic>? chart){
    if(chart==null)return const [];
    final result=<List<String>>[];
    for(final item in (chart['series'] as List? ?? []).take(4)){
      if(item is! Map)continue;
      final series=(item['name']??'').toString();
      for(final p in (item['data'] as List? ?? []).take(30)){
        if(p is! Map || p['value'] is! num)continue;
        final v=p['value'] as num;
        if(!v.isFinite)continue;
        result.add([series,(p['label']??'').toString(),v.toString()]);
      }
    }
    return result;
  }

  static Future<void> sharePdf({
    required String answer,
    Map<String,dynamic>? chart,
    Map<String,dynamic>? report,
  }) async {
    final regular=await PdfGoogleFonts.notoSansRegular();
    final bold=await PdfGoogleFonts.notoSansBold();
    final bodyStyle=pw.TextStyle(font:regular,fontSize:10);
    final heading=pw.TextStyle(font:bold,fontSize:15);
    final title=pw.TextStyle(font:bold,fontSize:19);
    final accent=PdfColor.fromHex('#2364D2');
    final doc=pw.Document(title:'SH Owner AI Report',
      author:'Smart Horeca Owner',compress:true);
    final data=rows(report), points=chartPoints(chart);
    doc.addPage(pw.MultiPage(
      pageFormat:PdfPageFormat.a4,
      margin:const pw.EdgeInsets.all(34),
      theme:pw.ThemeData.withFont(base:regular,bold:bold),
      maxPages:60,
      header:(context)=>pw.Container(
        padding:const pw.EdgeInsets.only(bottom:8),
        child:pw.Text('SMART HORECA  /  SH OWNER',
          style:pw.TextStyle(font:bold,fontSize:10,color:accent))),
      footer:(context)=>pw.Align(alignment:pw.Alignment.centerRight,
        child:pw.Text('${context.pageNumber} / ${context.pagesCount}',
          style:pw.TextStyle(font:regular,fontSize:8,
            color:PdfColors.grey700))),
      build:(context)=>[
        pw.Text('AI Smart Horeca Assistant',style:title),
        pw.SizedBox(height:14),
        pw.Text(answer,style:bodyStyle),
        if(report!=null) ...[
          pw.SizedBox(height:18),
          pw.Text((report['title']??'Отчёт').toString(),style:heading),
          for(final kpi in (report['kpis'] as List? ?? []).take(12))
            if(kpi is Map) pw.Padding(
              padding:const pw.EdgeInsets.only(top:6),
              child:pw.Text('${kpi['label']??''}: ${kpi['value']??''}',
                style:bodyStyle)),
          if(data.isNotEmpty) ...[
            pw.SizedBox(height:12),
            pw.Table.fromTextArray(
              data:data,
              headerStyle:pw.TextStyle(font:bold,fontSize:8),
              cellStyle:pw.TextStyle(font:regular,fontSize:8),
              headerDecoration:pw.BoxDecoration(color:PdfColors.blue50),
              cellAlignment:pw.Alignment.centerLeft,
            )
          ],
          for(final note in (report['notes'] as List? ?? []).take(6))
            pw.Padding(padding:const pw.EdgeInsets.only(top:8),
              child:pw.Text(note.toString(),style:bodyStyle)),
        ],
        if(points.isNotEmpty) ...[
          pw.SizedBox(height:16),
          pw.Text((chart?['title']??'Данные диаграммы').toString(),
            style:heading),
          pw.SizedBox(height:8),
          // Render verified chart measurements as a shareable table; never
          // fabricate missing dates, restaurant data, or chart points.
          pw.Table.fromTextArray(
            data:[['Ряд','Период / категория','Значение'],...points],
            headerStyle:pw.TextStyle(font:bold,fontSize:8),
            cellStyle:pw.TextStyle(font:regular,fontSize:8),
            headerDecoration:pw.BoxDecoration(color:PdfColors.blue50),
          ),
        ],
      ],
    ));
    await Printing.sharePdf(bytes:await doc.save(),
      filename:'SH_Owner_AI_Report.pdf');
  }
}
