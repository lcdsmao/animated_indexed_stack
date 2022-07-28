import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'AnimatedIndexedStack Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _children = [
    for (var i = 0; i < 3; i++)
      ListView.separated(
        itemCount: 100,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, j) => ListTile(
          leading: const Icon(Icons.woman),
          trailing: const Icon(Icons.man),
          title: Text('Page $i, Item $j'),
        ),
      )
  ];
  int _currIndex = 0;
  int? _lastIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimatedIndexedStack Demo'),
      ),
      body: AnimatedIndexedStack(
        index: _currIndex,
        duration: const Duration(milliseconds: 1000),
        transitionBuilder: (_, animation, child) {
          if (_lastIndex == null) return child;
          return FadeSlideHorizontalTransition(
            fromStartToEnd: _lastIndex! < _currIndex,
            animation: animation,
            child: child,
          );
        },
        children: _children,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currIndex,
        onTap: (i) {
          if (_currIndex != i) {
            setState(() {
              _lastIndex = _currIndex;
              _currIndex = i;
            });
          }
        },
        items: [
          for (var i = 0; i < _children.length; i++)
            BottomNavigationBarItem(
              icon: const Icon(Icons.star),
              label: 'Page $i',
            )
        ],
      ),
    );
  }
}

class FadeSlideHorizontalTransition extends StatelessWidget {
  const FadeSlideHorizontalTransition({
    Key? key,
    required this.fromStartToEnd,
    required this.animation,
    required this.child,
  }) : super(key: key);

  final bool fromStartToEnd;
  final Animation<double> animation;
  final Widget child;

  static final _fadeTween = CurveTween(curve: const Interval(0, 0.8));
  static final _fromStartTween = Tween(
    begin: const Offset(-0.5, 0),
    end: const Offset(0, 0),
  );
  static final _fromEndTween = Tween(
    begin: const Offset(0.5, 0),
    end: const Offset(0, 0),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation.drive(_fadeTween),
      child: AnimatedBuilder(
        animation: animation,
        builder: ((context, child) {
          final forward = animation.status == AnimationStatus.forward;
          final tween =
              fromStartToEnd ^ forward ? _fromStartTween : _fromEndTween;
          return FractionalTranslation(
            translation: tween.transform(animation.value),
            child: child,
          );
        }),
        child: child,
      ),
    );
  }
}

/////////

typedef IndexedChildTransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  Widget child,
);

class AnimatedIndexedStack extends StatefulWidget {
  const AnimatedIndexedStack({
    Key? key,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
    this.index = 0,
    required this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    required this.transitionBuilder,
    this.children = const [],
  }) : super(key: key);

  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;
  final int index;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final IndexedChildTransitionBuilder transitionBuilder;
  final List<Widget> children;

  static Widget defaultBuilder(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return child;
  }

  @override
  AnimatedIndexedStackState createState() => AnimatedIndexedStackState();
}

class AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _reverseAnimationController;

  List<GlobalKey> _globaKeys = [];
  int _currIndex = 0;
  int? _lastIndex;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _globaKeys = List.generate(widget.children.length, (_) => GlobalKey());
    _currIndex = widget.index;
    _setupAnimationController();
  }

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != _globaKeys.length) {
      _globaKeys = List.generate(widget.children.length, (_) => GlobalKey());
    }
    if (widget.duration != oldWidget.duration ||
        widget.reverseDuration != oldWidget.reverseDuration) {
      _animationController.dispose();
      _reverseAnimationController.dispose();
      _setupAnimationController();
    }
    if (_currIndex != widget.index) {
      _lastIndex = _currIndex;
      _currIndex = widget.index;

      final value = _animationController.value;
      final reverseValue = _reverseAnimationController.value;
      _animationController.value = reverseValue;
      _animationController.animateTo(
        1.0,
        curve: widget.switchInCurve,
      );
      _reverseAnimationController.value = value;
      _reverseAnimationController.animateBack(
        0.0,
        curve: widget.switchOutCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      sizing: widget.sizing,
      index: _currIndex,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Stack(
            fit: StackFit.passthrough,
            children: [
              if (i == _lastIndex && _switching)
                const SizedBox()
              else
                widget.transitionBuilder(
                  context,
                  _animationController.view,
                  KeyedSubtree(
                    key: _globaKeys[i],
                    child: widget.children[i],
                  ),
                ),
              if (i == _currIndex && _switching)
                IgnorePointer(
                  child: widget.transitionBuilder(
                    context,
                    _reverseAnimationController.view,
                    KeyedSubtree(
                      key: _globaKeys[_lastIndex!],
                      child: widget.children[_lastIndex!],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _setupAnimationController() {
    _animationController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: widget.duration,
    );
    _reverseAnimationController = AnimationController(
      vsync: this,
      value: 0.0,
      reverseDuration: widget.reverseDuration ?? widget.duration,
    );
    _reverseAnimationController.addStatusListener((status) {
      setState(() {
        _switching = status == AnimationStatus.reverse && _lastIndex != null;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reverseAnimationController.dispose();
    super.dispose();
  }
}
