import 'package:meta/meta.dart';

import '../errors/app_failure.dart';

/// Outcome of an operation that can fail in an expected way: either a value
/// or an [AppFailure]. Callers must handle both.
@immutable
sealed class Result<T> {
  const Result();

  /// A successful outcome holding [value].
  const factory Result.success(T value) = Success<T>;

  /// A failed outcome holding [failure].
  const factory Result.failure(AppFailure failure) = Failed<T>;

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Failed<T>;

  /// The value, or null when this is a failure.
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failed<T>() => null,
  };

  /// The failure, or null when this is a success.
  AppFailure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Failed<T>(:final failure) => failure,
  };

  /// Runs exactly one of the callbacks and returns its result.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Failed<T>(:final failure) => onFailure(failure),
  };

  /// Transforms the value; a failure passes through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result<R>.success(transform(value)),
    Failed<T>(:final failure) => Result<R>.failure(failure),
  };

  /// The value, or throws [AppException] for a failure.
  T getOrThrow() => switch (this) {
    Success<T>(:final value) => value,
    Failed<T>(:final failure) => throw AppException(failure),
  };

  /// Runs [operation] and converts a thrown [AppException] into a failure.
  /// Any other error is a defect and becomes an [UnexpectedFailure].
  static Future<Result<T>> guard<T>(Future<T> Function() operation) async {
    try {
      return Result<T>.success(await operation());
    } on AppException catch (exception) {
      return Result<T>.failure(exception.failure);
    } on Object catch (error) {
      return Result<T>.failure(UnexpectedFailure(error.runtimeType.toString()));
    }
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Success, value);
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);

  final AppFailure failure;
}
