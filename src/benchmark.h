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

		[[nodiscard]] std::vector<BenchmarkResult> RunAll(std::optional<std::string> categoryFilter = std::nullopt) const noexcept
		{
			std::vector<BenchmarkResult> results;
			results.reserve(m_Benchmarks.size());

			for (auto const& b : m_Benchmarks) 
			{
				if (categoryFilter && (*categoryFilter) != b.category)
				{
					continue;
				}

				results.emplace_back(RunBenchmark(b));
			}

			return results;
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