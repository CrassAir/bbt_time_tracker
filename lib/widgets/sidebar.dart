import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum SidebarItem { dashboard, history, chatLog, projects, settings }

class Sidebar extends StatelessWidget {
  final SidebarItem selected;
  final ValueChanged<SidebarItem> onSelect;
  final bool botRunning;

  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.botRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          right: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          if (Platform.isMacOS)
            GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              child: Container(
                height: 48,
                width: double.infinity,
                color: Colors.transparent,
              ),
            )
          else
            const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: botRunning ? Colors.green : Colors.red.shade400,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Qwen TT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (Platform.isMacOS) ...[
                  _WindowButton(
                    icon: Icons.remove,
                    onTap: () => windowManager.minimize(),
                  ),
                  const SizedBox(width: 4),
                  _WindowButton(
                    icon: Icons.crop_square,
                    onTap: () async {
                      final isMaximized = await windowManager.isMaximized();
                      if (isMaximized) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  _WindowButton(
                    icon: Icons.close,
                    onTap: () => windowManager.close(),
                    isClose: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            isSelected: selected == SidebarItem.dashboard,
            onTap: () => onSelect(SidebarItem.dashboard),
          ),
          _NavItem(
            icon: Icons.history_outlined,
            label: 'History',
            isSelected: selected == SidebarItem.history,
            onTap: () => onSelect(SidebarItem.history),
          ),
          _NavItem(
            icon: Icons.chat_outlined,
            label: 'Chat Log',
            isSelected: selected == SidebarItem.chatLog,
            onTap: () => onSelect(SidebarItem.chatLog),
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Projects',
            isSelected: selected == SidebarItem.projects,
            onTap: () => onSelect(SidebarItem.projects),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: selected == SidebarItem.settings,
            onTap: () => onSelect(SidebarItem.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || _hovering;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.blue.shade900.withValues(alpha: 0.4)
                : _hovering
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: isHighlighted
                    ? Colors.blue.shade300
                    : Colors.grey.shade500,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isHighlighted ? Colors.white : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isClose
                ? (_hovering ? Colors.red.shade700 : Colors.red.shade500)
                : (_hovering ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          child: Icon(
            widget.icon,
            size: 8,
            color: _hovering ? Colors.white : Colors.black.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
