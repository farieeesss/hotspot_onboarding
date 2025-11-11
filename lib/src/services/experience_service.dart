import 'package:dio/dio.dart';
import '../models/experience.dart';

class ExperienceService {
  ExperienceService({Dio? dio}) : _dio = dio ?? Dio();

  static const String baseUrl =
      'https://staging.chamberofsecrets.8club.co/v1/experiences?active=true';
  final Dio _dio;

  Future<List<Experience>> fetchExperiences() async {
    final response = await _dio.get(baseUrl);
    final data = response.data;
    final list = (data?['data']?['experiences'] as List<dynamic>? ?? []);
    return list
        .map((e) => Experience.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => (a.order ?? 999).compareTo(b.order ?? 999));
  }
}
