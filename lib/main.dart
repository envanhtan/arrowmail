import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:dio/dio.dart';
//import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
  void   main () async {

  WidgetsFlutterBinding.ensureInitialized();
await FlutterDownloader.initialize(debug: true);
 runApp(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const WebViewApp(),
    ),
  );
}


class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController _controller;
  late final bool permissionGranted;
  bool loading = false;
  bool error= false;
   Dio dio = Dio();
   final cookieManager = WebviewCookieManager();
var cookies = "";
   
  @override
  void initState() {


    dio.interceptors.add(InterceptorsWrapper(onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
        options.headers[HttpHeaders.cookieHeader] = cookies;
        handler.next(options);
    } )); 


    _getStoragePermission();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
    
  

    if (Platform.isAndroid) {
      final myAndroidController = controller.platform as AndroidWebViewController;
      
      myAndroidController.setOnShowFileSelector(_androidFilePicker);
    }

    controller 
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest:   (NavigationRequest request) async {
            error = false;
              if (request.url.contains("_download=1")) {
                String downloadFolder = "";
                await getDownloadPath().then((value) => (
                  downloadFolder = value ?? ""
                ));
               
                if(downloadFolder != "") {
                  var tempFile = "";
                  var originFileName = "";
                  var newFilePath = "";
                  try {
                    var uuid = Uuid();
                    tempFile = downloadFolder + "/" + uuid.v1();

                    var resp = await dio.download(request.url, tempFile,
                          onReceiveProgress: (received, total) {
                            if (total != -1) {
                              
                              setState(() {
                                if(total > received){
                                  loading = true;
                                }else {
                                  loading = false;
                                }
                              });
                            }
                          });

                   
                    for(var h in resp.headers.map.entries){
                      if(h.key == "content-disposition") { //"content-type
                        originFileName = h.value.first.replaceAll("attachment; filename=", "");
                        originFileName = originFileName.replaceAll("\"", "");
                        newFilePath = downloadFolder + "/" +  originFileName;
                      }
                    }

                    File originalFile = File(tempFile);
                    File renamedFile = await originalFile.rename(newFilePath);

                  }catch(e) {
                  }

                  if (Platform.isAndroid) {
                    //final params = SaveFileDialogParams(sourceFilePath: filePth);
                    //final finalFilePath = await FlutterFileDialog.saveFile(params: params);
                    final result = await OpenFile.open(newFilePath);
                  }
                }
               
                return NavigationDecision.prevent;
                
              } else {
                return NavigationDecision.navigate;
              }
            },

            onPageFinished:(url) async  {
              final gotCookies = await cookieManager.getCookies(url);
              if(gotCookies.isNotEmpty) {
                cookies = "";
              }
              for(var item in gotCookies){
                if(cookies != "") {
                  cookies += ";";
                }
                cookies += item.name + "=" + item.value;
              }
            },

            onWebResourceError: (WebResourceError webviewerrr) {
              error = true;
              //controller.loadHtmlString("");
            },
        )
      )
      ..loadRequest(
        Uri.parse('https://sacofficemail.gov.mm')
      );
      

     

       _controller = controller;
       super.initState();
  }


  Future<String?> getDownloadPath() async {
    Directory directory;

    if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getTemporaryDirectory();
    }
    return directory.path;
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        // Convert the file to base64
        List<int> fileBytes = await File(filePath).readAsBytes();

        //convert filepath into uri
        final filePath1 = (await getTemporaryDirectory()).uri.resolve(fileName);
        final file = await File.fromUri(filePath1).create(recursive: true);

        //convert file in bytes
        await file.writeAsBytes(fileBytes, flush: true);

        return [file.uri.toString()];
      }

      return [];
  }


  Future _getStoragePermission() async {
  if (await Permission.storage.request().isGranted) {
    setState(() {
      permissionGranted = true;
    });
  } else if (await Permission.storage.request().isPermanentlyDenied) {
    await openAppSettings();
  } else if (await Permission.storage.request().isDenied) {
    setState(() {
      permissionGranted = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SafeArea(
        child: 
        Stack(
          
         children: [
          
            loading ? const CircularProgressIndicator() : const Center(child: Text(" ")), 
            error ? Center(
              child: Stack(alignment: AlignmentDirectional.center, children: [
                TextButton(
                    style: ButtonStyle(
                      foregroundColor: MaterialStateProperty.all<Color>(Colors.red),
                    ),
                    onPressed: () {
                      _controller.reload();
                     },
                    child: const Text('Connection error! Click here to reload.'),
                  )
              ],)
              ) :   WebViewWidget(
              controller: _controller,
            ), 
        ],
    )
       ));
  }
}