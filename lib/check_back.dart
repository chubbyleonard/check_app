import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; 

class CheckBackPreview extends StatelessWidget {
  const CheckBackPreview({super.key});

  Widget _buildEndorseLine(int row, CheckProvider p) {
    Widget content;
    
    // Check if this specific row is designated for the signature
    if (p.endorseSignatureRow == row) {
      content = p.endorseSignatureBytes != null
          ? Image.memory(p.endorseSignatureBytes!, height: 35, fit: BoxFit.contain)
          : const SizedBox.shrink(); 
    } 
    // Otherwise, render it as handwriting text
    else {
      String text = '';
      if (row == 1) text = p.endorseLine1;
      if (row == 2) text = p.endorseLine2;
      if (row == 3) text = p.endorseLine3;
      if (row == 4) text = p.endorseLine4;
      
      content = Text(
        text,
        style: const TextStyle(fontFamily: 'Handwriting', fontSize: 20, color: Colors.black87),
      );
    }

    // Apply individual Tweak values per row for the UI
    double oX = 0.0; 
    double oY = 0.0;
    if (row == 1) { oX = TWEAK_UI_R1_X; oY = TWEAK_UI_R1_Y; }
    if (row == 2) { oX = TWEAK_UI_R2_X; oY = TWEAK_UI_R2_Y; }
    if (row == 3) { oX = TWEAK_UI_R3_X; oY = TWEAK_UI_R3_Y; }
    if (row == 4) { oX = TWEAK_UI_R4_X; oY = TWEAK_UI_R4_Y; }

    return SizedBox(
      height: 38.0, 
      width: 250, 
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: Offset(oX, oY), // Nudges this specific row independently
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CheckProvider>();

    // Dynamic stacking based on the UI Tweak setting
    List<Widget> rows = TWEAK_UI_FLIP_180
        ? [
            _buildEndorseLine(1, p),
            _buildEndorseLine(2, p),
            _buildEndorseLine(3, p),
            _buildEndorseLine(4, p),
          ]
        : [
            _buildEndorseLine(4, p),
            _buildEndorseLine(3, p),
            _buildEndorseLine(2, p),
            _buildEndorseLine(1, p),
          ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Stack(
        children: [
          // The Photorealistic Background Asset
          Image.asset(
            'assets/logos/check_back.png',
            fit: BoxFit.fill,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // The Dynamic Endorsement Overlay Grid 
          Positioned(
            top: 0,
            bottom: 0,
            right: 25, 
            child: Center(
              child: RotatedBox(
                quarterTurns: TWEAK_UI_FLIP_180 ? 1 : 3, // Flips based on UI setting
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: rows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}