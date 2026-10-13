/// Abstract use case contract.
///
/// Encapsulates a single business operation. Use cases are invoked from
/// the presentation layer (via Cubit/BLoC) and orchestrate the flow of
/// data between repositories.
///
/// [Type] is the return type of the use case.
/// [Params] is the input parameter type. Use [NoParams] when no input is
/// required.
abstract class UseCase<ReturnType, Params> {
  Future<ReturnType> call(Params params);
}

/// A parameter object for use cases that require no input.
class NoParams {
  const NoParams();
}
