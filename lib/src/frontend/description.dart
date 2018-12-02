import 'package:matcher/matcher.dart' as matcher;

class Description implements matcher.Description {
  final String text;

  Description(this.text);

  @override
  matcher.Description add(String text) => Description(this.text + text);

  @override
  matcher.Description addAll(
          String start, String separator, String end, Iterable list) =>
      Description(this.text + start + list.join(separator) + end);

  @override
  matcher.Description addDescriptionOf(value) =>
      Description(this.text + value.toString());

  @override
  int get length => text.length;

  @override
  matcher.Description replace(String text) => Description(text);

  @override
  String toString() => text;
}
