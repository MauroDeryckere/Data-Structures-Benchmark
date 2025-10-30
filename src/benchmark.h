#ifndef BENCHMARK_H
#define BENCHMARK_H

#include "singleton.h"

#include <functional>
#include <algorithm>
#include <numeric>

#include <string>
#include <vector>

#include <chrono>
#include <optional>


#include "benchmark_utils.h"

namespace Mau
{
	using BenchmarkFunc = std::function<void()>;

	class BenchmarkRegistry final : public MauCor::Singleton<BenchmarkRegistry>
	{
	public:
		struct BenchmarkResult final
		{
			std::string name;
			std::string category;

			size_t iterations;

			double avgMs;
			double totalMs;
			double medianMs;
			double minMs;
			double maxMs;
		};

		void Register(std::string const& name, std::string const& category, BenchmarkFunc const& func, size_t iterations = 10) noexcept
		{
			m_Benchmarks.emplace_back(name, category, func, iterations);
		}

		[[nodiscard]] std::vector<BenchmarkResult> RunAll(std::optional<std::vector <std::string>> categoryFilter = std::nullopt) const noexcept
		{
			std::vector<BenchmarkResult> results;
			results.reserve(m_Benchmarks.size());

			for (auto const& b : m_Benchmarks)
			{
				if (categoryFilter)
				{
					auto const& filters{ (*categoryFilter) };
					if (!filters.empty() &&
						std::find(filters.begin(), filters.end(), b.category) == filters.end())
					{
						continue;
					}
				}

				results.emplace_back(RunBenchmark(b));
			}

			return results;
		}

		static bool WriteCsv(std::filesystem::path const& filePath, std::string const& compilerInfo, std::vector<BenchmarkResult> const& results) noexcept
		{
			if (not std::filesystem::exists(filePath))
			{
				std::cerr << "Error: could not write to " << filePath << "\n";
				return false;
			}

			std::ofstream out(filePath);
			if (!out.is_open())
			{
				std::cerr << "Error: could not write to " << filePath << "\n";
				return false;
			}

			out.imbue(std::locale::classic());
			out << std::fixed << std::setprecision(6);
			out << "Compiler,Benchmark,Category,Iterations,Average(Ms),Total(Ms),Median(Ms),Min(Ms),Max(Ms)\n";

			for (auto const& r : results)
			{
				out << compilerInfo << ','
					<< r.name << ','
					<< r.category << ','
					<< r.iterations << ','
					<< r.avgMs << ','
					<< r.totalMs << ','
					<< r.medianMs << ','
					<< r.minMs << ','
					<< r.maxMs << '\n';
			}

			std::cout << "\nResults written to: " << filePath << "\n";
			return true;
		}

		static bool AppendToMasterResults(std::filesystem::path const& mergedFile, std::string const& compilerInfo, std::vector<BenchmarkResult> const& results) noexcept
		{
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
					<< r.avgMs << ','
					<< r.totalMs << ','
					<< r.medianMs << ','
					<< r.minMs << ','
					<< r.maxMs;

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
				return false;
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

			merged << "Compiler,Benchmark,Category,Iterations,Average(Ms),Total(Ms),Median(Ms),Min(Ms),Max(Ms)\n";
			for (auto const& line : oldLines)
			{
				merged << line << "\n";
			}


			return true;
			std::cout << "Appended results to: " << mergedFile << "\n";
		}

	private:
		friend class Singleton<BenchmarkRegistry>;
		BenchmarkRegistry() = default;
		virtual ~BenchmarkRegistry() override = default;

		struct BenchmarkEntry final
		{
			std::string name;
			std::string category;

			BenchmarkFunc func;
			size_t iterations;
		};

		std::vector<BenchmarkEntry> m_Benchmarks;


		static BenchmarkResult RunBenchmark(BenchmarkEntry const& entry) noexcept
		{
			using namespace std::chrono;

			std::vector<double> times;
			times.reserve(entry.iterations);

			for (size_t i{ 0 }; i < entry.iterations; ++i)
			{
				auto const start{ high_resolution_clock::now() };

				entry.func();

				auto const end{ high_resolution_clock::now() };

				auto const dur{ duration<double, std::milli>(end - start).count() };
				times.emplace_back(dur);
			}

			std::sort(times.begin(), times.end());
			double const total{ std::accumulate(times.begin(), times.end(), 0.0) };
			double const avg{ total / entry.iterations };
			double const median{ times[times.size() / 2] };
			double const min{ times.front() };
			double const max{ times.back() };

			return { entry.name, entry.category, entry.iterations, avg, total, median, min, max };
		}
	};

}

#endif