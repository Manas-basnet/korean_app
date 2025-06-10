import 'dart:developer' as dev;
import 'package:korean_language_app/core/errors/api_result.dart';
import 'package:korean_language_app/core/network/network_info.dart';
import 'package:korean_language_app/core/utils/exception_mapper.dart';

abstract class BaseRepository {
  final NetworkInfo networkInfo;
  
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);

  BaseRepository(this.networkInfo);
  Future<ApiResult<T>> handleRepositoryCall<T>(
    Future<ApiResult<T>> Function() remoteCall, {
    Future<ApiResult<T>> Function()? cacheCall,
    Future<void> Function(T data)? cacheData,
  }) async {
    if (!await networkInfo.isConnected) {
      if (cacheCall != null) {
        return cacheCall();
      }
      return ApiResult.failure(
        'No internet connection',
        FailureType.network,
      );
    }

    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await remoteCall();
        
        if (result.isSuccess && cacheData != null) {
          try {
            await cacheData(result.data as T);
          } catch (e) {
            dev.log('Cache error: $e');
          }
        }
        
        return result;
      } catch (e) {
        lastException = e as Exception;
        
        if (attempt == maxRetries) {
          break;
        }
        
        final delay = Duration(seconds: initialRetryDelay.inSeconds * attempt);
        await Future.delayed(delay);
        
        dev.log('Retry attempt $attempt failed: $e. Retrying in ${delay.inSeconds}s...');
      }
    }
    
    return ExceptionMapper.mapExceptionToApiResult(lastException!);
  }

  Future<ApiResult<T>> handleCacheFirstCall<T>(
    Future<ApiResult<T>> Function() cacheCall,
    Future<ApiResult<T>> Function() remoteCall, {
    Future<void> Function(T data)? cacheData,
  }) async {
    final cacheResult = await cacheCall();
    
    if (cacheResult.isSuccess) {
      return cacheResult;
    }
    
    if (!await networkInfo.isConnected) {
      return ApiResult.failure(
        'No internet connection and no cached data',
        FailureType.network,
      );
    }

    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await remoteCall();
        
        if (result.isSuccess && cacheData != null) {
          try {
            await cacheData(result.data as T);
          } catch (e) {
            dev.log('Cache error: $e');
          }
        }
        
        return result;
      } catch (e) {
        lastException = e as Exception;
        
        if (attempt == maxRetries) {
          break;
        }
        
        final delay = Duration(seconds: initialRetryDelay.inSeconds * attempt);
        await Future.delayed(delay);
        
        dev.log('Retry attempt $attempt failed: $e. Retrying in ${delay.inSeconds}s...');
      }
    }
    
    return ExceptionMapper.mapExceptionToApiResult(lastException!);
  }
}