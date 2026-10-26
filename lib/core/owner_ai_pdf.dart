import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Creates a shareable report *on the device* from the reply the user has
/// already received. No additional Smart Horeca, iiko or OpenAI calls.
class OwnerAiPdf {
  const OwnerAiPdf._();

  static List<String> paragraphs(String text) {
    // A huge single PDF widget cannot span a page. Keep paragraphs bounded
    // while preserving the full assistant response and Cyrillic/Azeri text.
    final chunks=<String>[];
    for(final raw in text.replaceAll('\r\n','\n').split('\n')){
      var line=raw.trim();
      if(line.isEmpty)continue;
      while(line.length>700){
        var cut=line.lastIndexOf(' ',700);
        if(cut<350)cut=700;
        chunks.add(line.substring(0,cut).trim());
        line=line.substring(cut).trim();
      }
      if(line.isNotEmpty)chunks.add(line);
    }
    return chunks;
  }

  static List<Map<String, dynamic>> chartPoints(Map<String,dynamic>? chart) {
    final values=<Map<String,dynamic>>[];
    final series=chart?['series'];
    if(series is! List)return values;
    for(final s in series.take(3)){
      if(s is! Map||s['data'] is! List)continue;
      final name=(s['name']??'').toString();
      for(final point in (s['data'] as List).take(12)){
        if(point is! Map)continue;
        final value=point['value'];
        if(value is! num || !value.isFinite)continue;
        final label=(point['label']??'').toString();
        values.add({'label':name.isEmpty?label:'$name / $label','value':value.toDouble()});
      }
    }
    return values.take(18).toList(growable:false);
  }

  static List<pw.Widget> reportWidgets(Map<String,dynamic>? report, pw.Font regular,pw.Font bold) {
    if(report==null)return const [];
    final widgets=<pw.Widget>[];
    final title=(report['title']??'AI Report').toString();
    widgets.add(pw.SizedBox(height:14));
    widgets.add(pw.Text(title,style:pw.TextStyle(font:bold,fontSize:15,color:PdfColors.blueGrey900)));
    if((report['subtitle']??'').toString().trim().isNotEmpty){
      widgets.add(pw.Text(report['subtitle'].toString(),style:pw.TextStyle(font:regular,fontSize:10)));
    }
    final kpis=report['kpis'];
    if(kpis is List)for(final item in kpis.take(8)){
      if(item is! Map)continue;
      widgets.add(pw.Padding(padding:const pw.EdgeInsets.only(top:5),child:pw.Row(children:[
        pw.Expanded(child:pw.Text((item['label']??'').toString(),style:pw.TextStyle(font:regular,fontSize:10))),
        pw.Text((item['value']??'').toString(),style:pw.TextStyle(font:bold,fontSize:10))
      ])));
    }
    final cols=report['columns'];
    final rows=report['rows'];
    if(cols is List && cols.isNotEmpty && rows is List){
      final headers=cols.take(8).map((c)=>c is Map?(c['label']??'').toString():c.toString()).toList();
      final data=<List<String>>[];
      for(final row in rows.take(45)){
        if(row is! List)continue;
        data.add(List.generate(headers.length,(i)=>i<row.length?(row[i]??'').toString():''));
      }
      widgets.add(pw.SizedBox(height:12));
      widgets.add(pw.TableHelper.fromTextArray(
        headers:headers,
        data:data,
        headerStyle:pw.TextStyle(font:bold,color:PdfColors.white,fontSize:8),
        cellStyle:pw.TextStyle(font:regular,fontSize:8),
        headerDecoration:const pw.BoxDecoration(color:PdfColors.blueGrey800),
        cellAlignment:pw.Alignment.centerLeft,
        cellPadding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:5),
        border:pw.TableBorder.all(color:PdfColors.blueGrey100,width:.4)
      ));
    }
    final notes=report['notes'];
    if(notes is List)for(final note in notes.take(6)){
      widgets.add(pw.Padding(padding:const pw.EdgeInsets.only(top:5),
        child:pw.Text(note.toString(),style:pw.TextStyle(font:regular,fontSize:9,color:PdfColors.blueGrey700))));
    }
    return widgets;
  }

  static Future<void> share({
    required String answer,
    Map<String,dynamic>? chart,
    Map<String,dynamic>? report,
  }) async {
    // Noto Sans includes both Russian Cyrillic and Azerbaijani Latin glyphs.
    final regular=await PdfGoogleFonts.notoSansRegular();
    final bold=await PdfGoogleFonts.notoSansBold();
    final now=DateTime.now();
    final doc=pw.Document(
      title:'SH Owner AI - Smart Horeca',
      author:'Smart Horeca',
      theme:pw.ThemeData.withFont(base:regular,bold:bold),
    );
    final accent=PdfColor.fromHex('#1A629C');
    final points=chartPoints(chart);
    final children=<pw.Widget>[
      pw.Text('AI Smart Horeca Assistant',
        style:pw.TextStyle(font:bold,fontSize:20,color:accent)),
      pw.SizedBox(height:6),
      pw.Text('SH Owner · ${now.day.toString().padLeft(2,'0')}.${now.month.toString().padLeft(2,'0')}.${now.year}',
        style:pw.TextStyle(font:regular,fontSize:10,color:PdfColors.blueGrey600)),
      pw.Divider(thickness:1,color:PdfColors.blueGrey200),
      ...paragraphs(answer).map((p)=>pw.Padding(
        padding:const pw.EdgeInsets.only(top:7),
        child:pw.Text(p,style:pw.TextStyle(font:regular,fontSize:10.5,lineSpacing:3))
      )),
    ];
    if(points.isNotEmpty){
      final maxAbs=points.map((e)=>(e['value'] as double).abs()).reduce(math.max);
      children.add(pw.SizedBox(height:15));
      children.add(pw.Text((chart?['title']??'Диаграмма').toString(),
        style:pw.TextStyle(font:bold,fontSize:15,color:accent)));
      for(final point in points){
        final value=point['value'] as double;
        final ratio=maxAbs>0?(value.abs()/maxAbs):0.0;
        children.add(pw.Padding(padding:const pw.EdgeInsets.only(top:7),child:pw.Column(
          crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
            pw.Text('${point['label']}  ·  ${value.toStringAsFixed(2)}',
              style:pw.TextStyle(font:regular,fontSize:9)),
            pw.SizedBox(height:3),
            pw.Container(width:math.max(2,math.min(410,410*ratio)),height:7,
              decoration:pw.BoxDecoration(color:accent,borderRadius:pw.BorderRadius.circular(3)))
          ]
        )));
      }
    }
    children.addAll(reportWidgets(report,regular,bold));
    doc.addPage(pw.MultiPage(
      pageFormat:PdfPageFormat.a4,
      margin:const pw.EdgeInsets.fromLTRB(34,40,34,40),
      maxPages:100,
      footer:(context)=>pw.Align(alignment:pw.Alignment.centerRight,
        child:pw.Text('Smart Horeca · ${context.pageNumber}',
          style:pw.TextStyle(font:regular,fontSize:8,color:PdfColors.blueGrey500))),
      build:(context)=>children
    ));
    final filename='SH_Owner_AI_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.pdf';
    await Printing.sharePdf(bytes:await doc.save(),filename:filename);
  }
}
