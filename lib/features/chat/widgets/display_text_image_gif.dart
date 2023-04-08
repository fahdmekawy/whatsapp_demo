import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_ui/common/enums/message_enum.dart';
import 'package:whatsapp_ui/features/chat/widgets/video_player_item.dart';

class DisplayTextImageGif extends StatelessWidget {
  final String message;
  final MessageEnum messageEnum;

  const DisplayTextImageGif(
      {Key? key, required this.message, required this.messageEnum})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return messageEnum == MessageEnum.text
        ? Text(
            message,
            style: const TextStyle(fontSize: 16),
          )
        : messageEnum == MessageEnum.video
            ? VideoPlayerItem(videoUrl: message)
            : messageEnum == MessageEnum.gif
                ? CachedNetworkImage(imageUrl: message)
                : CachedNetworkImage(imageUrl: message);
  }
}
