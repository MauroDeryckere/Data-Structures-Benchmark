#include <iostream>
#include <string>

#include <filesystem>
#include <fstream>

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

int main()
{
	std::string const info{ GetCompilerInfo() };
	std::cout << info << "\n";

	std::string safeName{ info };
	for (char& c : safeName) 
	{
		if (c == ' ' || c == '(' || c == ')' || c == ':') c = '_';
	}

	std::filesystem::path const resultsDir{ std::filesystem::path(PROJECT_RESULTS_DIR) };
	std::filesystem::create_directories(resultsDir);
	std::filesystem::path const filePath{ resultsDir / ("compiler_info_" + safeName + ".txt") };

	std::cout << "Writing results to: " << filePath << std::endl;

	std::ofstream out(filePath);
	if (out.is_open())
	{
		out << info << "\n";
	}
	else {
		std::cerr << "Error: could not write to " << filePath << "\n";
		return 1;
	}
	//std::string test;
	//std::cin >> test;
	return 0;
}