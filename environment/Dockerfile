# Linux environment for re-running the simulations with the same FDS release as the paper (FDS 6.11.0).
# The official NIST Linux bundle includes FDS, Smokeview and the MPI library it was built with.
# PowerShell 7 is added so the analysis scripts (analyze.ps1, analyze60.ps1, compare_with_reference.ps1) also run here;
# the figure scripts need Windows (System.Drawing, Smokeview rendering).
#
#   docker build -t arad-fds -f environment/Dockerfile .
#   docker run --rm -it -v "$PWD/simulations:/work/simulations" arad-fds
#   (inside)  cd /work/simulations && ./run_simulations.sh arad_low
FROM ubuntu:24.04

ARG FDS_URL=https://github.com/firemodels/fds/releases/download/FDS-6.11.0/FDS-6.11.0_SMV-6.11.0_lnx.sh
ARG FDS_SHA256=a285ea0b6c8ae09289d541b989244b716273601e794916e17ee26c293d956dc5

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget procps \
 && rm -rf /var/lib/apt/lists/*

# FDS 6.11.0 + Smokeview 6.11.0: download, verify, unpack the archive embedded after the __TARFILE_FOLLOWS__ marker
RUN wget -q -O /tmp/fds.sh "$FDS_URL" \
 && echo "$FDS_SHA256  /tmp/fds.sh" | sha256sum -c - \
 && mkdir -p /opt/FDS6 \
 && SKIP=$(awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' /tmp/fds.sh) \
 && tail -n +"$SKIP" /tmp/fds.sh | tar -xz --strip-components=1 -C /opt/FDS6 \
 && rm /tmp/fds.sh

# PowerShell 7 (Microsoft package repository) for the analysis scripts
RUN wget -q -O /tmp/ms.deb https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
 && dpkg -i /tmp/ms.deb && rm /tmp/ms.deb \
 && apt-get update && apt-get install -y --no-install-recommends powershell \
 && rm -rf /var/lib/apt/lists/*

# FDS and its bundled MPI on the PATH (the bundle keeps MPI under bin/INTEL or bin/openmpi depending on the build)
ENV PATH=/opt/FDS6/bin:/opt/FDS6/bin/INTEL/bin:/opt/FDS6/bin/openmpi/bin:$PATH \
    LD_LIBRARY_PATH=/opt/FDS6/bin/INTEL/lib:/opt/FDS6/bin/openmpi/lib:/opt/FDS6/bin/LIB64 \
    OMP_NUM_THREADS=1

RUN useradd -m fds
USER fds
WORKDIR /work
COPY --chown=fds:fds . /work
CMD ["bash", "-lc", "fds -version; exec bash"]
