class Tbb < Formula
  desc "Rich and complete approach to parallelism in C++"
  homepage "https://github.com/oneapi-src/oneTBB"
  url "https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2021.5.0.tar.gz"
  sha256 "e5b57537c741400cf6134b428fc1689a649d7d38d9bb9c1b6d64f092ea28178a"
  license "Apache-2.0"
  revision 2

  bottle do
    sha256 cellar: :any,                 arm64_monterey: "81dea309acb3a9f5fb2ac30c4e9a915d91108f314cea56028f5fed96be58fcd6"
    sha256 cellar: :any,                 arm64_big_sur:  "48465c108c4ad1d794dac93decf5f53838eec82f1b097084a80c910b9735d96c"
    sha256 cellar: :any,                 monterey:       "db3cbe833ec513f70b679c56ba624bf567c2fe93de6fc5145ebd6ca4cbeef3a8"
    sha256 cellar: :any,                 big_sur:        "be99ceff29b46c05ef7037ca4a9158fb753604af2ccb9bb3a5bb6eb67608e636"
    sha256 cellar: :any,                 catalina:       "a3b5165a52a69d50a1cedc5e9f636ffb9cd66162cd74554ee5c6f077b34da75e"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "ed987863be8c658d41a3d8793d20dc78b86ef5dc694b281d3056fc3a71a7388c"
  end

  depends_on "cmake" => :build
  depends_on "python@3.10" => [:build, :test]
  depends_on "swig" => :build

  # Fix installation of Python components
  # See https://github.com/oneapi-src/oneTBB/issues/343
  patch :DATA

  def install
    args = *std_cmake_args + %w[
      -DTBB_TEST=OFF
      -DTBB4PY_BUILD=ON
    ]

    mkdir "build" do
      system "cmake", "..", *args, "-DCMAKE_INSTALL_RPATH=#{rpath}"
      system "make"
      system "make", "install"
      system "make", "clean"
      system "cmake", "..", *args, "-DBUILD_SHARED_LIBS=OFF"
      system "make"
      lib.install Dir["**/libtbb*.a"]
    end

    cd "python" do
      ENV.append_path "CMAKE_PREFIX_PATH", prefix.to_s
      ENV["LDFLAGS"] = "-rpath #{opt_lib}" if OS.mac?
      python = Formula["python@3.10"].opt_bin/"python3"

      ENV["TBBROOT"] = prefix
      system python, *Language::Python.setup_install_args(prefix),
                     "--install-lib=#{prefix/Language::Python.site_packages(python)}"
    end

    inreplace_files = prefix.glob("rml/CMakeFiles/irml.dir/{flags.make,build.make,link.txt}")
    inreplace inreplace_files, Superenv.shims_path/ENV.cxx, ENV.cxx if OS.linux?
  end

  test do
    (testpath/"sum1-100.cpp").write <<~EOS
      #include <iostream>
      #include <tbb/blocked_range.h>
      #include <tbb/parallel_reduce.h>

      int main()
      {
        auto total = tbb::parallel_reduce(
          tbb::blocked_range<int>(0, 100),
          0.0,
          [&](tbb::blocked_range<int> r, int running_total)
          {
            for (int i=r.begin(); i < r.end(); ++i) {
              running_total += i + 1;
            }

            return running_total;
          }, std::plus<int>()
        );

        std::cout << total << std::endl;
        return 0;
      }
    EOS

    system ENV.cxx, "sum1-100.cpp", "--std=c++14", "-L#{lib}", "-ltbb", "-o", "sum1-100"
    assert_equal "5050", shell_output("./sum1-100").chomp

    system Formula["python@3.10"].opt_bin/"python3", "-c", "import tbb"
  end
end

__END__
diff --git a/python/CMakeLists.txt b/python/CMakeLists.txt
index 1d2b05f..81ba8de 100644
--- a/python/CMakeLists.txt
+++ b/python/CMakeLists.txt
@@ -49,7 +49,7 @@ add_test(NAME python_test
                  -DPYTHON_MODULE_BUILD_PATH=${PYTHON_BUILD_WORK_DIR}/build
                  -P ${PROJECT_SOURCE_DIR}/cmake/python/test_launcher.cmake)

-install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${PYTHON_BUILD_WORK_DIR}/build/
+install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${PYTHON_BUILD_WORK_DIR}/
         DESTINATION .
         COMPONENT tbb4py)
