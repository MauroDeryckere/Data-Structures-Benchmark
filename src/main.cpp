#include <iostream>
#include <string>
#include <vector>

#include <filesystem>
#include <fstream>

#include <chrono>

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

struct BenchmarkResult final
{
	std::string name;
	size_t iterations;
	double avgUs;
	double totalUs;
};

using BenchmarkFunc = void(*)();

[[nodiscard]] BenchmarkResult RunBenchmark(std::string const& name, BenchmarkFunc func, size_t iterations = 1'000) noexcept
{
	using namespace std::chrono;
	auto const start{ high_resolution_clock::now() };

	for (size_t i{ 0 }; i < iterations; ++i)
	{
		func();
	}

	auto const end{ high_resolution_clock::now() };
	auto const totalUs{ duration<double, std::micro>(end - start).count() };
	auto const avgUs{ totalUs / iterations };

	return { name, iterations, avgUs, totalUs };
}

void BenchmarkLoop()
{
	int x{ 0 };
	std::vector<int> vec;

	for (int i{ 0 }; i < 100'000; ++i)
	{
		x += i;
		x *= 2;
		vec.emplace_back(x);
		vec.back() %= 1000;
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

	std::vector<BenchmarkResult> results;
	results.emplace_back(RunBenchmark("Loop", BenchmarkLoop, 10));
	results.emplace_back(RunBenchmark("Loop2", BenchmarkLoop, 10));
	results.emplace_back(RunBenchmark("Loop3", BenchmarkLoop, 10));

	std::ofstream out(filePath);
	if (!out.is_open())
	{
		std::cerr << "Error: could not write to " << filePath << "\n";
		return 1;
	}

	// Write CSV header

	out.imbue(std::locale::classic());
	out << std::fixed << std::setprecision(6);
	out << "Compiler,Benchmark,Iterations,Average(us),Total(us)\n";


	for (auto const& r : results)
	{
		out << compilerInfo << ','
			<< r.name << ','
			<< r.iterations << ','
			<< r.avgUs << ','
			<< r.totalUs << '\n';

		std::cout << r.name << ": " << r.avgUs << " us avg (" << r.totalUs << " us total)\n";
	}

	std::cout << "\nResults written to: " << filePath << "\n";



	std::filesystem::path const mergedFile{ resultsDir / "all_results.csv" };

	std::vector<std::string> oldLines;
	if (std::filesystem::exists(mergedFile))
	{
		std::ifstream in(mergedFile);
		std::string line;
		bool firstLine{ true };
		while (std::getline(in, line))
		{
			if (firstLine) { firstLine = false; continue; }
			oldLines.push_back(line);
		}
	}

	for (auto const& r : results)
	{
		std::ostringstream oss;
		oss << compilerInfo << ','
			<< r.name << ','
			<< r.iterations << ','
			<< r.avgUs << ','
			<< r.totalUs;
		oldLines.push_back(oss.str());
	}

	std::sort(oldLines.begin(), oldLines.end(),
		[](std::string const& a, std::string const& b)
		{
			auto const aNameStart{ a.find(',') + 1 };
			auto const bNameStart{ b.find(',') + 1 };
			auto const aNameEnd{ a.find(',', aNameStart) };
			auto const bNameEnd{ b.find(',', bNameStart) };
			std::string const aName{ a.substr(aNameStart, aNameEnd - aNameStart) };
			std::string const bName{ b.substr(bNameStart, bNameEnd - bNameStart) };
			if (aName == bName)
			{
				return a < b;
			}
			return aName < bName;
		});

	std::ofstream merged(mergedFile, std::ios::trunc);

	if (!merged.is_open())
	{
		std::cerr << "Error: could not write to " << mergedFile << "\n";
		return 1;
	}

	merged.imbue(std::locale::classic());
	merged << std::fixed << std::setprecision(6);
	merged << "Compiler,Benchmark,Iterations,Average(us),Total(us)\n";
	for (auto const& line : oldLines)
	{
		merged << line << "\n";
	}

	std::cout << "Appended results to: " << mergedFile << "\n";

	return 0;
}