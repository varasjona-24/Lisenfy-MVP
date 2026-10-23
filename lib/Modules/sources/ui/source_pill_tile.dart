import 'package:flutter/material.dart';
import '../domain/source_pill_data.dart';

// ============================
// 🧱 UI: PILL DE ORIGEN
// ============================
class SourcePillTile extends StatelessWidget {
  const SourcePillTile({super.key, required this.data});

  final SourcePillData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textColor = data.forceDarkText ? Colors.black : Colors.white;
    final subColor = data.forceDarkText
        ? Colors.black87
        : Colors.white.withValues(alpha: 0.88);
    final circleBg = data.forceDarkText
        ? Colors.black.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.18);
    final iconColor = data.forceDarkText ? Colors.black : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: data.gradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ],
          ),
          child: InkWell(
            onTap: data.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleBg,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.30),
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(data.icon, color: iconColor, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: textColor.withValues(alpha: 0.9),
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
