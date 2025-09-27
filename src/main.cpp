#include <iostream>

int main()
{
	#if defined(_MSC_VER)
	    std::cout << "MSVC "
	        << _MSC_VER << " (full: " << _MSC_FULL_VER << ")\n";
	#elif defined(__clang__)
	    std::cout << "Clang "
	        << __clang_major__ << "."
	        << __clang_minor__ << "."
	        << __clang_patchlevel__ << "\n";
	#elif defined(__GNUC__)
	    std::cout << "GCC "
	        << __GNUC__ << "."
	        << __GNUC_MINOR__ << "."
	        << __GNUC_PATCHLEVEL__ << "\n";
	#else
	    std::cout << "Unknown compiler\n";
	#endif

	return 0;
}