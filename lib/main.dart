import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

// main.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Provider<DataUsaApiClient>(
      create: (context) => const DataUsaApiClient(),
      child: const MaterialApp(
        home: HomePage(),
      ),
    );
  }
}

// home.dart

class HomePage extends StatelessWidget {
  const HomePage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Years'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Open "loaded" demo'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Provider<DetailState>.value(
                      value: const DetailState.loaded(
                        year: 2022,
                        measure: Measure(
                          year: 2022,
                          population: 425484,
                          nation: 'United States',
                        ),
                      ),
                      child: const DetailLayout(),
                    );
                  },
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Open "loading" demo'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Provider<DetailState>.value(
                      value: const DetailState.loading(2022),
                      child: const DetailLayout(),
                    );
                  },
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Open "not data" demo'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Provider<DetailState>.value(
                      value: const DetailState.noData(2022),
                      child: const DetailLayout(),
                    );
                  },
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Open "error" demo'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Provider<DetailState>.value(
                      value: const DetailState.unknownError(
                        year: 2022,
                        error: 'Oops',
                      ),
                      child: const DetailLayout(),
                    );
                  },
                ),
              );
            },
          ),
          for (var i = DateTime.now().year; i > 2000; i--)
            ListTile(
              title: Text('$i'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: RouteSettings(arguments: i),
                    builder: (context) {
                      return const DetailScreen();
                    },
                  ),
                );
              },
            )
        ],
      ),
    );
  }
}

// api.dart

class DataUsaApiClient {
  const DataUsaApiClient({
    this.endpoint = 'https://datausa.io/api/data',
  });

  final String endpoint;

  Future<Measure?> getMeasure(int year) async {
    final uri =
        Uri.parse('$endpoint?drilldowns=Nation&measures=Population&year=$year');
    final result = await get(uri);
    final body = jsonDecode(result.body);
    final data = body['data'] as List<dynamic>;
    if (data.isNotEmpty) {
      return Measure.fromJson(data.first as Map<String, Object?>);
    }
    return null;
  }
}

class Measure {
  const Measure({
    required this.year,
    required this.population,
    required this.nation,
  });

  factory Measure.fromJson(Map<String, Object?> json) {
    return Measure(
      nation: json['Nation'] as String,
      population: (json['Population'] as num).toInt(),
      year: (json['ID Year'] as num).toInt(),
    );
  }

  final int year;
  final int population;
  final String nation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Measure &&
          year == other.year &&
          population == other.population &&
          nation == other.nation);

  @override
  int get hashCode => Object.hash(year, population, nation);
}

class DemoDataUsaApiClient implements DataUsaApiClient {
  const DemoDataUsaApiClient(this.measure);

  final Measure measure;

  @override
  String get endpoint => '';

  @override
  Future<Measure?> getMeasure(int year) {
    return Future.value(measure);
  }
}

// state.dart

abstract class DetailState {
  const DetailState(this.year);
  final int year;

  const factory DetailState.notLoaded(int year) = NotLoadedDetailState;
  const factory DetailState.loading(int year) = LoadingDetailState;
  const factory DetailState.noData(int year) = NoDataDetailState;
  const factory DetailState.loaded({
    required int year,
    required Measure measure,
  }) = LoadedDetailState;
  const factory DetailState.unknownError({
    required int year,
    required dynamic error,
  }) = UnknownErrorDetailState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DetailState &&
          runtimeType == other.runtimeType &&
          year == other.year);

  @override
  int get hashCode => runtimeType.hashCode ^ year;
}

class NotLoadedDetailState extends DetailState {
  const NotLoadedDetailState(int year) : super(year);
}

class LoadedDetailState extends DetailState {
  const LoadedDetailState({
    required int year,
    required this.measure,
  }) : super(year);

  final Measure measure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoadedDetailState && measure == other.measure);

  @override
  int get hashCode => runtimeType.hashCode ^ measure.hashCode;
}

class NoDataDetailState extends DetailState {
  const NoDataDetailState(int year) : super(year);
}

class LoadingDetailState extends DetailState {
  const LoadingDetailState(int year) : super(year);
}

class UnknownErrorDetailState extends DetailState {
  const UnknownErrorDetailState({
    required int year,
    required this.error,
  }) : super(year);

  final dynamic error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnknownErrorDetailState &&
          year == other.year &&
          error == other.error);

  @override
  int get hashCode => Object.hash(super.hashCode, error.hashCode);
}

// notifier.dart

class DetailNotifier extends ValueNotifier<DetailState> {
  DetailNotifier({
    required int year,
    required this.api,
  }) : super(DetailState.notLoaded(year));

  final DataUsaApiClient api;

  int get year => value.year;

  Future<void> refresh() async {
    if (value is! LoadingDetailState) {
      value = DetailState.loading(year);
      try {
        final result = await api.getMeasure(year);
        if (result != null) {
          value = DetailState.loaded(
            year: year,
            measure: result,
          );
        } else {
          value = DetailState.noData(year);
        }
      } catch (error) {
        value = DetailState.unknownError(
          year: year,
          error: error,
        );
      }
    }
  }
}

// detail.dart

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final year = ModalRoute.of(context)!.settings.arguments as int;
    return ChangeNotifierProvider<DetailNotifier>(
      create: (context) {
        final notifier = DetailNotifier(
          year: year,
          api: context.read<DataUsaApiClient>(),
        );
        notifier.refresh();
        return notifier;
      },
      child: ProxyProvider<DetailNotifier, DetailState>(
        update: (context, value, previous) => value.value,
        child: const DetailLayout(),
      ),
    );
  }
}

class DetailLayout extends StatelessWidget {
  const DetailLayout({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DetailState>(
      builder: (context, state, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Year ${state.year}'),
          ),
          body: () {
            if (state is NotLoadedDetailState || state is LoadingDetailState) {
              return const LoadingDetailLayout();
            }
            if (state is LoadedDetailState) {
              return LoadedDetailLayout(state: state);
            }
            if (state is UnknownErrorDetailState) {
              return UnknownErrorDetailLayout(state: state);
            }
            return const NoDataDetailLayout();
          }(),
        );
      },
    );
  }
}

class LoadedDetailLayout extends StatelessWidget {
  const LoadedDetailLayout({
    Key? key,
    required this.state,
  }) : super(key: key);

  final LoadedDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            state.measure.nation,
            style: theme.textTheme.headline5,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state.measure.population}',
                style: theme.textTheme.headline4,
              ),
              Icon(
                Icons.people,
                color: theme.textTheme.headline4?.color,
                size: theme.textTheme.headline4?.fontSize,
              ),
            ],
          ),
        ],
      ),
    );
    ;
  }
}

class NoDataDetailLayout extends StatelessWidget {
  const NoDataDetailLayout({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No data'),
    );
  }
}

class UnknownErrorDetailLayout extends StatelessWidget {
  const UnknownErrorDetailLayout({
    Key? key,
    required this.state,
  }) : super(key: key);

  final UnknownErrorDetailState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Failed : ${state.error}'),
    );
  }
}

class LoadingDetailLayout extends StatelessWidget {
  const LoadingDetailLayout({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
