import 'recorded_video.dart';

/// Rules for numbering takes and choosing the best one, kept free of storage
/// so they can be tested directly.
class TakeLibrary {
  const TakeLibrary._();

  /// One more than the highest take number used for [scriptId], so deleting a
  /// take never makes a number come back.
  static int nextTakeNumber(List<RecordedVideo> takes, String scriptId) {
    var highest = 0;
    for (final take in takes) {
      if (take.scriptId == scriptId && take.takeNumber > highest) highest = take.takeNumber;
    }
    return highest + 1;
  }

  /// Numbers takes saved before numbering existed (take number 0) in the order
  /// they were recorded, after any numbers the script already uses.
  static List<RecordedVideo> numberUnnumberedTakes(List<RecordedVideo> takes) {
    final unnumbered = takes.where((t) => t.takeNumber == 0).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (unnumbered.isEmpty) return takes;

    final numbered = List.of(takes);
    for (final take in unnumbered) {
      final position = numbered.indexWhere((t) => t.id == take.id);
      numbered[position] = take.copyWith(takeNumber: nextTakeNumber(numbered, take.scriptId));
    }
    return numbered;
  }

  /// Stars [takeId] as its script's best take (unstarring the previous one),
  /// or unstars it if it is already the best.
  static List<RecordedVideo> toggleBestTake(List<RecordedVideo> takes, String takeId) {
    final target = takes.where((t) => t.id == takeId).firstOrNull;
    if (target == null) return takes;
    final makeBest = !target.isBest;
    return [
      for (final take in takes)
        if (take.id == takeId)
          take.copyWith(isBest: makeBest)
        else if (take.scriptId == target.scriptId && take.isBest && makeBest)
          take.copyWith(isBest: false)
        else
          take,
    ];
  }

  /// Best takes, newest first: what gets exported for editing.
  static List<RecordedVideo> bestTakes(List<RecordedVideo> takes) =>
      takes.where((t) => t.isBest).toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
}
