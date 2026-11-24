import 'package:flutter/material.dart';
import '../services/sleep_timer_manager.dart';

/// Bottom Sheet for selecting Sleep Timer duration
void showSleepTimerSheet(BuildContext context, {VoidCallback? onTimerChanged}) {
  final manager = SleepTimerManager();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return AnimatedBuilder(
        animation: manager,
        builder: (context, _) {
          final bottomInset = MediaQuery.of(context).padding.bottom;
          return SafeArea(
            top: true,
            bottom: true,
            minimum: const EdgeInsets.only(top: 8),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, (bottomInset + 16.0) / 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.timer_outlined, color: Color(0xFFE50914), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '睡眠定時器 (Sleep Timer)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (manager.isActive) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '倒數中：${manager.formattedTime}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE50914),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Option Tiles
                  Material(
                    color: const Color(0xFF2A2A2A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: SleepTimerMode.values.map((mode) {
                        final isSelected = manager.mode == mode;
                        return InkWell(
                          onTap: () {
                            manager.setTimer(mode);
                            Navigator.of(ctx).pop();
                            onTimerChanged?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  mode == SleepTimerMode.off
                                      ? '已關閉睡眠定時器'
                                      : '已設定睡眠定時：${mode.label}',
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF2A2A2A),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE50914).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              border: Border(
                                bottom: mode != SleepTimerMode.values.last
                                    ? const BorderSide(color: Colors.white10, width: 0.5)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: isSelected ? const Color(0xFFE50914) : Colors.white38,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    mode.label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected && manager.isActive)
                                  Text(
                                    manager.formattedTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFE50914),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
