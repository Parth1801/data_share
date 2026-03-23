import 'package:flutter/material.dart';

Widget getListViewBuilder({
  required int itemCount,
  required Widget Function(int index) itemBuilder,

  ScrollPhysics scrollphysics = const NeverScrollableScrollPhysics(),
  Axis scrollDirection = Axis.vertical,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  ScrollController? controller,
  reverse = false,
}) {
  return ListView.builder(
    controller: controller,
    reverse: reverse,
    scrollDirection: scrollDirection,
    padding: padding,
    itemCount: itemCount,
    shrinkWrap: true,
    physics: scrollphysics,
    itemBuilder: (context, index) => itemBuilder(index),
  );
}
