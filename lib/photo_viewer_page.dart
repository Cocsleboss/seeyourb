import 'package:flutter/material.dart';
import 'dart:io';
import '/models/PhotoRdv.dart';

class PhotoViewerPage extends StatefulWidget {
  final List<PhotoRdv> photoRdvs;
  final int initialIndex;

  const PhotoViewerPage({
    Key? key,
    required this.photoRdvs,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _PhotoViewerPageState createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }
  
  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photoRdvs[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text("RDV du ${currentPhoto.date.day}/${currentPhoto.date.month}/${currentPhoto.date.year}"),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photoRdvs.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Center(
                child: Image.file(
                  File(widget.photoRdvs[index].photoPath),
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          Positioned(
            left: 10,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 50, color: Colors.white),
              onPressed: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
            ),
          ),
          Positioned(
            right: 10,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: IconButton(
              icon: Icon(Icons.arrow_forward, size: 50, color: Colors.white),
              onPressed: () {
                if (_currentIndex < widget.photoRdvs.length - 1) {
                  _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
