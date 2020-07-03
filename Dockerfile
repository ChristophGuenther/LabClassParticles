FROM fedora:31
MAINTAINER Manuel Giffels, giffels@gmail.com, 2019
USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
RUN dnf -y --nogpg install vim nano emacs git wget bzip2 ca-certificates sudo python3 python3-pip python3-devel\
    root nodejs python3-jupyroot python3-root.x86_64 root-montecarlo-pythia8.x86_64 \
    pythia8 pythia8-devel.x86_64 python3-jsmva patch.x86_64 rsync.x86_64 openblas.x86_64 \
    openblas-devel.x86_64 lapack.x86_64 lapack-devel.x86_64 atlas.x86_64 atlas-devel.x86_64 \
    gcc-gfortran.x86_64 gcc-c++.x86_64 libffi libffi-devel openssl openssl-devel&& dnf clean all
RUN dnf -y --nogpg update && dnf clean all

# Add configurations
RUN mkdir -p /install
ADD requirements.txt /install/requirements.txt
RUN pip3 install --no-cache-dir -r /install/requirements.txt -I

ADD pythia-root.patch /install/pythia-root.patch
RUN patch /usr/include/Pythia8/PythiaStdlib.h < /install/pythia-root.patch

# Install Tini
RUN wget --quiet https://github.com/krallin/tini/releases/download/v0.18.0/tini && \
    echo "12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855 *tini" | sha256sum -c - && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Configure environment
ENV SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100

ENV HOME=/home/$NB_USER

ADD fix-permissions /usr/local/bin/fix-permissions
# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER
USER $NB_USER
RUN mkdir -p $HOME/.local/share/jupyter
RUN rsync -az /usr/lib64/python3.7/site-packages/JupyROOT/ $HOME/.local/share/jupyter
USER root
RUN jupyter labextension install @jupyterlab/hub-extension
RUN fix-permissions $HOME

EXPOSE 8888
WORKDIR $HOME

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting
COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/
RUN fix-permissions /etc/jupyter/

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_USER
