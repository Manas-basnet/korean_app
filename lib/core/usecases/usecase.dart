import 'package:korean_language_app/core/errors/api_result.dart';

abstract class UseCase<Type, Params> {
  Future<ApiResult<Type>> execute(Params params);
}

abstract class UseCaseNoParams<Type> {
  Future<ApiResult<Type>> execute();
}

class NoParams {
  const NoParams();
}