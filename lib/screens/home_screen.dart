import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/translation_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late final stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    _messages.add(
      const _ChatMessage(
        text:
            'Hi! I can help translate and summarize. Tap + to attach docs/images or use the mic to speak.',
        fromUser: false,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Show the floating translator only when the app is being detached.
    // `paused`/`inactive` happen frequently on Android and can hide the UI unexpectedly.
    if (state == AppLifecycleState.detached) {
      _showFloatingTranslator();
    }
  }

  Future<void> _showFloatingTranslator() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final requestResult = await FlutterOverlayWindow.requestPermission();
      granted = requestResult ?? false;
    }
    if (!granted) {
      return;
    }

    final isActive = await FlutterOverlayWindow.isActive();
    if (!isActive) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        width: 100,
        height: 100,
      );
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Speech recognition is not available on this device.')),
      );
      return;
    }

    if (mounted) {
      setState(() => _isListening = true);
    }
    await _speech.listen(
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) {
        _messageController.text = result.recognizedWords;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final provider = Provider.of<TranslationProvider>(context, listen: false);
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _messageController.clear();
    });
    _scrollToBottom();

    await provider.translateText(text);
    if (!mounted) return;

    if (provider.errorMessage.isNotEmpty) {
      setState(() {
        _messages.add(_ChatMessage(
            text: provider.errorMessage, fromUser: false, isError: true));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      if (provider.summary.isNotEmpty) {
        _messages.add(_ChatMessage(
            text: 'Summary:\n${provider.summary}', fromUser: false));
      }
      _messages.add(_ChatMessage(
        text:
            'Dialect (${provider.currentDialect}):\n${provider.translatedText}',
        fromUser: false,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _openAttachmentMenu() async {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.description_outlined)),
                title: const Text('Attach Document'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickAttachment(imageOnly: false);
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.image_outlined)),
                title: const Text('Attach Image'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickAttachment(imageOnly: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    final provider = Provider.of<TranslationProvider>(context, listen: false);
    final result = imageOnly
        ? await FilePicker.platform.pickFiles(type: FileType.image)
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            withData: true,
            allowedExtensions: ['txt', 'md', 'pdf', 'doc', 'docx'],
          );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: 'Attached: ${file.name}',
          fromUser: true,
          attachment: true,
        ),
      );
    });
    _scrollToBottom();

    if (imageOnly) {
      setState(() {
        _messages.add(
          const _ChatMessage(
            text:
                'Image attached. For full-screen real-time OCR translation, tap the scan icon on the top bar or use the floating icon after minimizing the app.',
            fromUser: false,
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    if (ext != 'txt' && ext != 'md') {
      setState(() {
        _messages.add(
          const _ChatMessage(
            text:
                'Document uploaded. Auto-summary currently supports .txt/.md directly in app. For PDF/DOCX, wire backend document parser to continue.',
            fromUser: false,
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    String content = '';
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!, allowMalformed: true);
    } else if (file.path != null && file.path!.isNotEmpty) {
      content = await File(file.path!).readAsString();
    }

    if (content.trim().isEmpty) {
      return;
    }

    final prompt = content.length > 5000 ? content.substring(0, 5000) : content;
    await provider.translateText(prompt);
    if (!mounted) return;

    setState(() {
      if (provider.summary.isNotEmpty) {
        _messages.add(
          _ChatMessage(
              text: 'Document Summary:\n${provider.summary}', fromUser: false),
        );
      }
      if (provider.translatedText.isNotEmpty) {
        _messages.add(
          _ChatMessage(
            text: 'Translated Extract:\n${provider.translatedText}',
            fromUser: false,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  Future<void> _startRealtimeOverlay() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Floating translator is available on Android only.')),
      );
      return;
    }

    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final requestResult = await FlutterOverlayWindow.requestPermission();
      granted = requestResult ?? false;
    }

    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant overlay permission.')),
      );
      return;
    }

    final isActive = await FlutterOverlayWindow.isActive();
    if (!isActive) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        width: 100,
        height: 100,
      );
    }

    await const MethodChannel('com.example.gov_translator/app_channel')
        .invokeMethod('moveToBackground');
  }

  void _openDrawerItem(String label) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label clicked')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TranslationProvider>(
      builder: (context, provider, _) {
        const dialectOptions = [
          'Kelate',
          'Hokkien',
          'Cantonese',
          'English',
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF3F7FF),
          drawer: Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    color: const Color(0xFF0D47A1),
                    child: const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Account'),
                    onTap: () => _openDrawerItem('Account'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Chat History'),
                    onTap: () => _openDrawerItem('Chat History'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () => _openDrawerItem('Settings'),
                  ),
                ],
              ),
            ),
          ),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color(0xFF0D47A1),
            centerTitle: false,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gov Translate Bot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Translate and summarize',
                  style: TextStyle(fontSize: 12, color: Color(0xFFBBDEFB)),
                ),
              ],
            ),
            actions: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dialectOptions.contains(provider.currentDialect)
                      ? provider.currentDialect
                      : 'English',
                  dropdownColor: const Color(0xFF1976D2),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: dialectOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.setDialect(value);
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: _startRealtimeOverlay,
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.screen_search_desktop_outlined,
                    size: 20,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                tooltip: 'Realtime screen translation',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(message: _messages[index]);
                  },
                ),
              ),
              if (provider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Bot is processing...',
                      style: TextStyle(color: Colors.black54)),
                ),
              Container(
                color: const Color(0xFFEAF2FF),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD3E3FF)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _openAttachmentMenu,
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Color(0xFF1976D2)),
                              tooltip: 'Attach document or image',
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: 'Message translator bot',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleListening,
                              icon: Icon(
                                _isListening
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_none_rounded,
                                color: _isListening
                                    ? Colors.red
                                    : const Color(0xFF1976D2),
                              ),
                              tooltip: 'Speech to text',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: _sendMessage,
                        child:
                            const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isError;
  final bool attachment;

  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.isError = false,
    this.attachment = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align =
        message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.fromUser
        ? const Color(0xFFDDEBFF)
        : (message.isError ? const Color(0xFFFFEBEE) : Colors.white);

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(message.fromUser ? 12 : 4),
            bottomRight: Radius.circular(message.fromUser ? 4 : 12),
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachment) ...[
              const Padding(
                padding: EdgeInsets.only(top: 1, right: 6),
                child: Icon(Icons.attach_file_rounded,
                    size: 16, color: Color(0xFF1976D2)),
              ),
            ],
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  height: 1.35,
                  color: message.isError
                      ? const Color(0xFFC62828)
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
