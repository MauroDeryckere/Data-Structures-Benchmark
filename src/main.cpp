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

uint32_t constexpr TEST_MAP_SIZE{ 10'000 };

[[nodiscard]] static constexpr float GenerateValue(uint32_t i) noexcept
{
	return static_cast<float>((i * 37) % 1000) / 1000.0f;
}

[[nodiscard]] static std::string GetCompilerInfo() noexcept
{
#if defined(__clang__)
	return "Clang " + std::to_string(__clang_major__) + "." +
		std::to_string(__clang_minor__) + "." +
		std::to_string(__clang_patchlevel__);
#elif defined(_MSC_VER)
	return "MSVC " + std::to_string(_MSC_VER) +
		" (full: " + std::to_string(_MSC_FULL_VER) + ")";
#elif defined(__GNUC__) && !defined(__clang__)
	return "GCC " + std::to_string(__GNUC__) + "." +
		std::to_string(__GNUC_MINOR__) + "." +
		std::to_string(__GNUC_PATCHLEVEL__);
#else
	return "Unknown compiler";
#endif
}

void BenchmarkFlatMapIterate()
{
	for (auto const& item : g_TestFlatMap)
	{
		item.second *= 2;
	}
}

void BenchmarkMapIterate()
{
	for (auto& item : g_TestMap)
	{
		item.second *= 2;
	}
}


void BenchmarkUnorderedMapIterate()
{
	for (auto& item : g_TestUnorderedMap)
	{
		item.second *= 2;
	}
}

void BenchmarkFlatMapEmplace()
{
	g_TestFlatMap.clear();

	for (uint32_t i{ 0 }; i < TEST_MAP_SIZE; ++i)
	{
		float const value{ static_cast<float>((i * 37) % 1000) / 1000.0f };
		g_TestFlatMap.emplace(i, value);
	}
}

void BenchmarkMapEmplace()
{	
	g_TestMap.clear();

	for (uint32_t i{ 0 }; i < TEST_MAP_SIZE; ++i)
	{
		float const value{ static_cast<float>((i * 37) % 1000) / 1000.0f };
		g_TestMap.emplace(i, value);
	}
}


void BenchmarkUnorderedMapEmplace()
{
	g_TestUnorderedMap.clear();

	for (uint32_t i{ 0 }; i < TEST_MAP_SIZE; ++i)
	{
		float const value{ static_cast<float>((i * 37) % 1000) / 1000.0f };
		g_TestUnorderedMap.emplace(i, value);
	}
}

int main()
{
	std::string const compilerInfo{ GetCompilerInfo() };
	std::cout << "Running benchmarks for: " << compilerInfo << "\n";

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

	std::ofstream out(filePath);
	if (!out.is_open())
	{
		std::cerr << "Error: could not write to " << filePath << "\n";
		return 1;
	}

	// Write CSV header
	out.imbue(std::locale::classic());
	out << std::fixed << std::setprecision(6);
	out << "Compiler,Benchmark,Category,Iterations,Average(us),Total(us),Median(Us),Min(Us),Max(Us)\n";

	for (auto const& r : results)
	{
		out << compilerInfo << ','
			<< r.name << ','
			<< r.category << ','
			<< r.iterations << ','
			<< r.avgUs << ','
			<< r.totalUs << ','
			<< r.medianUs << ','
			<< r.minUs << ','
			<< r.maxUs << '\n';

		std::cout << r.name << ": " << r.avgUs << " us avg (" << r.totalUs << " us total)\n";
	}

	std::cout << "\nResults written to: " << filePath << "\n";



	std::filesystem::path const mergedFile{ resultsDir / "all_results.csv" };

	std::vector<std::string> oldLines;
	if (std::filesystem::exists(mergedFile))
	{
		std::ifstream in(mergedFile);
		std::string line;
		int skip{ 0 };
		while (std::getline(in, line))
		{
			if (skip != 2) 
			{
				++skip;
				continue; 
			}

			oldLines.emplace_back(line);
		}
	}

	for (auto const& r : results)
	{
		std::ostringstream oss;
		oss << compilerInfo << ','
			<< r.name << ','
			<< r.category << ','
			<< r.iterations << ','
			<< r.avgUs << ','
			<< r.totalUs << ','
			<< r.medianUs << ','
			<< r.minUs << ','
			<< r.maxUs;

		oldLines.emplace_back(oss.str());
	}

	auto getField
	{
		[](std::string const& line, size_t index) -> std::string 
		{
			size_t start{ 0};
			for (size_t i{ 0 }; i < index; ++i)
			{
				start = line.find(',', start) + 1;
			}
			size_t const end{ line.find(',', start) };

			return line.substr(start, end - start);
		} 
	};

	std::sort(oldLines.begin(), oldLines.end(),
		[getField](std::string const& a, std::string const& b)
		{
			std::string const aCategory{ getField(a, 2) };
			std::string const bCategory{ getField(b, 2) };

			if (aCategory == bCategory) 
			{
				std::string const aName{ getField(a, 1) };
				std::string const bName{ getField(b, 1) };
				return aName < bName;
			}

			return aCategory < bCategory;
		});

	std::ofstream merged(mergedFile, std::ios::trunc);

	if (!merged.is_open())
	{
		std::cerr << "Error: could not write to " << mergedFile << "\n";
		return 1;
	}

	merged.imbue(std::locale::classic());
	merged << std::fixed << std::setprecision(6);

	// Get current timestamp
	auto const now = std::chrono::system_clock::now();
	std::time_t const now_c = std::chrono::system_clock::to_time_t(now);
	std::tm tm{};
	#ifdef _WIN32
		localtime_s(&tm, &now_c);
	#else
		localtime_r(&now_c, &tm);
	#endif
	char timeBuf[64];
	std::strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S", &tm);

	// Write date row
	merged << "Date:," << timeBuf << "\n";

	merged << "Compiler,Benchmark,Category,Iterations,Average(us),Total(us),Median(Us),Min(Us),Max(Us)\n";
	for (auto const& line : oldLines)
	{
		merged << line << "\n";
	}

	std::cout << "Appended results to: " << mergedFile << "\n";

	return 0;
}