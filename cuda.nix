# Shared SDK selection for GPU hosts, the CUDA shell and the compiled smoke test.
# Use a Nixpkgs instance that permits NVIDIA's CUDA licenses, not global cudaSupport.
{ pkgs }:
let
  cuda = pkgs.cudaPackages; # Nixpkgs' widely-supported default, currently CUDA 12.9.
  toolkit = cuda.cudatoolkit; # Complete upstream compatibility layout for SDK consumers.
  architecture = if cuda.cudaAtLeast "13.0" then "75" else "52";
in
{
  inherit toolkit;
  packages = [
    toolkit # nvcc, cuda-gdb, compute-sanitizer, headers and CUDA math/runtime libraries.
    cuda.cudnn
  ];
  shell = (pkgs.mkShell.override { stdenv = cuda.backendStdenv; }) {
    packages = [
      toolkit
      cuda.cudnn
      pkgs.cmake
      pkgs.ninja
    ];
    env = {
      CUDA_PATH = "${toolkit}";
      CUDACXX = "${toolkit}/bin/nvcc";
      CUDAHOSTCXX = "${cuda.backendStdenv.cc}/bin/c++";
    };
  };
  # New Nix builds use split redistributables and their hooks, not the SDK join.
  smoke = cuda.backendStdenv.mkDerivation {
    pname = "cuda-check";
    version = "1";
    dontUnpack = true;
    __structuredAttrs = true;
    strictDeps = true;
    nativeBuildInputs = [
      cuda.cuda_nvcc
      pkgs.autoAddDriverRunpath
    ];
    buildInputs = [ cuda.cuda_cudart ];
    buildPhase = ''
      runHook preBuild
      nvcc -ccbin ${cuda.backendStdenv.cc}/bin/c++ \
        -I${pkgs.lib.getOutput "include" cuda.cuda_cudart}/include -L${pkgs.lib.getLib cuda.cuda_cudart}/lib \
        --cudart shared -arch=compute_${architecture} \
        ${./cuda-check.cu} -o cuda-check
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 cuda-check "$out/bin/cuda-check"
      runHook postInstall
    '';
    # Do not fake a GPU test inside the Nix build sandbox.
    doCheck = false;
    meta.mainProgram = "cuda-check";
  };
}
