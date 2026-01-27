import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late VideoPlayerController _videoController;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the video player with the local asset
    _videoController = VideoPlayerController.asset('assets/videos/tutorial.mp4');

    // Initialize the controller and store the Future for loading
    _initializeVideoPlayerFuture = _videoController.initialize().then((_) {
      // Optional: Set video to loop
      _videoController.setLooping(false);
      // Optional: Set initial volume
      _videoController.setVolume(1.0);
      setState(() {}); // Update UI when video is ready
    }).catchError((error) {
      debugPrint('Video initialization error: $error');
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _navigateBack() {
    Navigator.of(context).pop();
  }

  void _shareVideo() async {
    const videoUrl = 'https://blupos.com/demo-video';
    const message = 'Check out BluPOS Point of Sale System: $videoUrl';
    await Share.share(message);
  }

  void _openWhatsAppSupport() async {
    const phoneNumber = '+254703103960';
    const message = 'Hi, I need help with BluPOS Point of Sale System';
    final url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _openEmailContact() async {
    const email = 'otienot75@gmail.com';
    const subject = 'BluPOS Business Inquiry - Point of Sale System';
    const body = 'Dear BluPOS Team,\n\nI am interested in learning more about your Point of Sale solutions.\n\nBest regards,\n[Your Name]';

    final url = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Widget _buildBluPOSAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🏢 BLUPOS BUSINESS SOLUTIONS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '🏪 Point of Sale Excellence',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Trusted by Businesses Across East Africa',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Enterprise POS • Mobile Payments • Analytics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'BluPOS Ecosystem v2.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade200, // Consistent theme background
      body: SafeArea(
        child: Column(
          children: [
            // Section 1: Landscape Video Player - True Landscape Aspect Ratio
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9, // True landscape aspect ratio
                  child: FutureBuilder(
                    future: _initializeVideoPlayerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        // If the VideoPlayerController has finished initialization, use
                        // the data it provides to limit the aspect ratio of the video.
                        return VideoPlayer(_videoController);
                      } else {
                        // If the VideoPlayerController is still initializing, show a
                        // loading spinner.
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),

            // Section 2: Back Button
            Container(
              width: double.infinity,
              height: 50 * 1.35, // 67.5px - matching project button height
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _navigateBack,
                child: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF182A62), // Project blue
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Section 3: Business Info Container
            Container(
              height: 180,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEC620), // Yellow background
                borderRadius: BorderRadius.circular(16), // Rounded square
              ),
              child: _buildBluPOSAboutCard(),
            ),

            // Section 4: Action Buttons Container
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Share Video Button
                  Container(
                    width: double.infinity,
                    height: 50 * 1.35, // 67.5px - matching project button height
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: _shareVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182A62), // Project blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Icon(Icons.video_library),
                          Text('Share Video'),
                        ],
                      ),
                    ),
                  ),

                  // WhatsApp Button
                  Container(
                    width: double.infinity,
                    height: 50 * 1.35, // 67.5px - matching project button height
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: _openWhatsAppSupport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182A62), // Project blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Icon(Icons.chat), // WhatsApp icon
                          Text('WhatsApp'),
                        ],
                      ),
                    ),
                  ),

                  // Email Button
                  Container(
                    width: double.infinity,
                    height: 50 * 1.35, // 67.5px - matching project button height
                    child: ElevatedButton(
                      onPressed: _openEmailContact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182A62), // Project blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Icon(Icons.email),
                          Text('Email'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}