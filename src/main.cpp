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
	double avgMs;
	double totalMs;
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
	auto const totalMs{ duration<double, std::milli>(end - start).count() };
	auto const avgMs{ totalMs / iterations };

	return { name, iterations, avgMs, totalMs };
}

void BenchmarkLoop()
{
	int x{ 0 };
	std::vector<int> vec;

	//for (int i{ 0 }; i < 100'000; ++i)
	for (int i{ 0 }; i < 100; ++i)
	{
		x += i;
		x *= 2;
		vec.emplace_back(x);
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
	results.emplace_back(RunBenchmark("Loop", BenchmarkLoop, 10'000));

	std::ofstream out(filePath);
	if (!out.is_open())
	{
		std::cerr << "Error: could not write to " << filePath << "\n";
		return 1;
	}

	// Write CSV header
	out << "Compiler,Benchmark,Iterations,Average(ms),Total(ms)\n";

	for (auto const& r : results)
	{
		out << compilerInfo << ','
			<< r.name << ','
			<< r.iterations << ','
			<< r.avgMs << ','
			<< r.totalMs << '\n';

		std::cout << r.name << ": " << r.avgMs << " ms avg (" << r.totalMs << " ms total)\n";
	}

	std::cout << "\nResults written to: " << filePath << "\n";



	std::filesystem::path const mergedFile{ resultsDir / "all_results.csv" };
	// Check if master file exists; if not, create header
	bool needsHeader = !std::filesystem::exists(mergedFile);

	std::ofstream merged(mergedFile, std::ios::app);
	if (!merged.is_open())
	{
		std::cerr << "Error: could not write to " << mergedFile << "\n";
		return 1;
	}

	if (needsHeader)
	{
		merged << "Compiler,Benchmark,Iterations,Average(ms),Total(ms)\n";
	}

	// Append results
	for (auto const& r : results)
	{
		merged << compilerInfo << ','
			<< r.name << ','
			<< r.iterations << ','
			<< r.avgMs << ','
			<< r.totalMs << '\n';
	}

	std::cout << "Appended results to: " << mergedFile << "\n";

	return 0;
}