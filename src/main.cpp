#include <iostream>
#include <filesystem>
#include <fstream>

#include <SG14/flat_map.h>
#include <map>
#include <unordered_map>

#include <string>
#include <vector>

#include "benchmark.h"

stdext::flat_map<int, float> g_TestFlatMap;
std::map<int, float> g_TestMap;
std::unordered_map<int, float> g_TestUnorderedMap;

uint32_t constexpr TEST_MAP_SIZE{ 1'000'000 };

void BenchmarkFlatMapIterate()
{
	float sum = 0.0f;

	for (auto const& item : g_TestFlatMap)
	{
		sum += item.second * 2.0f;
		DO_NOT_OPTIMIZE(sum);
	}
	CLOBBER_MEMORY();
}

void BenchmarkMapIterate()
{
	float sum = 0.0f;

	for (auto& item : g_TestMap)
	{
		sum += item.second * 2.0f;
		DO_NOT_OPTIMIZE(sum);
	}
	CLOBBER_MEMORY();
}


void BenchmarkUnorderedMapIterate()
{
	float sum = 0.0f;

	for (auto& item : g_TestUnorderedMap)
	{
		sum += item.second * 2.0f;
		DO_NOT_OPTIMIZE(sum);
	}
	CLOBBER_MEMORY();
}

void BenchmarkFlatMapEmplace()
{
	g_TestFlatMap.clear();

	for (uint32_t i{ 0 }; i < TEST_MAP_SIZE; ++i)
	{
		float const value{ Mau::GenerateValue(i) };
		g_TestFlatMap.emplace(i, value);
	}
}

void BenchmarkMapEmplace()
{	
	g_TestMap.clear();

	for (uint32_t i{ 0 }; i < TEST_MAP_SIZE; ++i)
	{
		float const value{ Mau::GenerateValue(i) };
		g_TestMap.emplace(i, value);
	}
}


void BenchmarkUnorderedMapEmplace()
{
	g_TestUnorderedMap.clear();

	for (uint32_t i{ 0 }; i < TEST_MAP_SIZE; ++i)
	{
		float const value{ Mau::GenerateValue(i) };
		g_TestUnorderedMap.emplace(i, value);
	}
}

int main()
{
	std::string const compilerInfo{ Mau::GetCompilerInfo() };
	std::cout << "Running benchmarks for: " << compilerInfo << "\n";

	// Sanitize compiler info for file name
	std::string safeName{ compilerInfo };
	for (char& c : safeName) 
	{
		if (c == ' ' || c == '(' || c == ')' || c == ':') c = '_';
	}

	std::filesystem::path const resultsDir{ std::filesystem::path(PROJECT_RESULTS_DIR) };
	std::filesystem::create_directories(resultsDir);
	std::filesystem::path const filePath{ resultsDir / ("bench_results_" + safeName + ".csv") };

#pragma region benchmarking
	auto& benchmarkReg{ Mau::BenchmarkRegistry::GetInstance() };
	benchmarkReg.Register("Flat Map Emplace", "Map Emplace", BenchmarkFlatMapEmplace, 10);
	benchmarkReg.Register("Map Emplace", "Map Emplace", BenchmarkMapEmplace, 10);
	benchmarkReg.Register("Unordered Map Emplace", "Map Emplace", BenchmarkUnorderedMapEmplace, 10);

	benchmarkReg.Register("Flat Map Iterate", "Map Iterate", BenchmarkFlatMapIterate, 10);
	benchmarkReg.Register("Map Iterate", "Map Iterate", BenchmarkMapIterate, 10);
	benchmarkReg.Register("Unordered Map Iterate", "Map Iterate", BenchmarkUnorderedMapIterate, 10);

	auto const results{ benchmarkReg.RunAll() };
#pragma endregion

	benchmarkReg.WriteCsv(filePath, compilerInfo, results);

	std::filesystem::path const mergedFile{ resultsDir / "all_results.csv" };

	benchmarkReg.AppendToMasterResults(mergedFile, compilerInfo, results);

	return 0;
}