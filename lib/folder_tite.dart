import 'package:flutter/material.dart';

enum FolderMenu {
  play,
  playNext,
  addToQueue,
  addToPlaylist,
  hide,
  deleteFromDevice,
}

class FolderTile extends StatelessWidget {
  final String name;
  final String path;
  final int songCount;
  final VoidCallback? onTap;
  final ValueChanged<FolderMenu>? onMenuAction;

  const FolderTile({
    super.key,
    required this.name,
    required this.path,
    required this.songCount,
    this.onTap,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme; // ✅ YAHAN sahi jagah

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Folder icon
            Container(
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: cs.tertiary, // ✅ ONLY folder tile accent
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.folder,
                color: cs.onTertiary, // ✅ readable icon color
                size: 30,
              ),
            ),

            const SizedBox(width: 12),

            // Name + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitleText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // 3 dots – vertical
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showFolderOptionsSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleText() {
    final s = songCount == 1 ? '1 song' : '$songCount songs';
    return '$s · $path';
  }

  void _showFolderOptionsSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true, // ⬅️ important: full-height feel + drag
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.30,
          maxChildSize: 0.90,
          builder: (context, scrollCtrl) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // top drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // header row – folder icon + name + close
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // list of actions (scrollable)
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _MenuTile(
                        icon: Icons.play_arrow_rounded,
                        text: 'Play',
                        onTap: () {
                          Navigator.pop(context);
                          onMenuAction?.call(FolderMenu.play);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.play_circle_outline,
                        text: 'Play next',
                        onTap: () {
                          Navigator.pop(context);
                          onMenuAction?.call(FolderMenu.playNext);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.queue_music,
                        text: 'Add to queue',
                        onTap: () {
                          Navigator.pop(context);
                          onMenuAction?.call(FolderMenu.addToQueue);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.playlist_add,
                        text: 'Add to playlist',
                        onTap: () {
                          Navigator.pop(context);
                          onMenuAction?.call(FolderMenu.addToPlaylist);
                        },
                      ),

                      const Divider(height: 24, color: Colors.white24),

                      _MenuTile(
                        icon: Icons.visibility_off_outlined,
                        text: 'Hide',
                        onTap: () {
                          Navigator.pop(context);
                          onMenuAction?.call(FolderMenu.hide);
                        },
                      ),
                      const SizedBox(height: 4),
                      _MenuTile(
                        icon: Icons.delete_outline,
                        text: 'Delete from device',
                        isDestructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          onMenuAction?.call(FolderMenu.deleteFromDevice);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.text,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color iconColor =
    isDestructive ? const Color(0xFFFF5252) : Colors.white70;
    final Color textColor =
    isDestructive ? const Color(0xFFFF5252) : Colors.white;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 16),
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
