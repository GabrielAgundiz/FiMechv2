import 'package:flutter/material.dart';

class ProfileData extends StatelessWidget {
  const ProfileData({
    super.key,
    required this.onPressed,
    required this.title,
    required this.value,
    this.icon = Icons.edit,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String title, value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                maxLines: 2,
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(width: 8,),
            Icon(icon, size: 18,color: Colors.green[300],),
          ],
        ),
      ),
    );
  }
}
