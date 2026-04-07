import 'package:flutter/material.dart';

class SettingsInfoTile extends StatelessWidget {
  const SettingsInfoTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.subtitleStyle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha((0.1 * 255).round()),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: DefaultTextStyle.merge(
        style: subtitleStyle ?? const TextStyle(),
        child: subtitle,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
