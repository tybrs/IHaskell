FROM fpco/stack-build:lts-14.23

# Install all necessary Ubuntu packages
RUN apt-get update && apt-get install -y python3-pip libgmp-dev libmagic-dev libtinfo-dev libzmq3-dev libcairo2-dev libpango1.0-dev libblas-dev liblapack-dev gcc g++ && \
    rm -rf /var/lib/apt/lists/*

# Install Jupyter notebook
RUN pip3 install -U jupyter

ENV LANG en_US.UTF-8
ENV NB_USER polyglot
ENV NB_UID 1000
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

# Set up a working directory for IHaskell
RUN mkdir ${HOME}/ihaskell
WORKDIR ${HOME}/ihaskell

USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_UID}

# Set up stack
COPY ihaskell/stack.yaml stack.yaml
RUN stack config set system-ghc --global true

# Install dependencies for IHaskell
COPY ihaskell/ihaskell.cabal ihaskell.cabal
COPY ihaskell/ipython-kernel ipython-kernel
COPY ihaskell/ghc-parser ghc-parser
COPY ihaskell/ihaskell-display ihaskell-display

USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_UID}

RUN stack build --only-snapshot

# Install IHaskell itself. Don't just COPY . so that
# changes in e.g. README.md don't trigger rebuild.
COPY ihaskell/src ${HOME}/ihaskell/src
COPY ihaskell/html ${HOME}/ihaskell/html
COPY ihaskell/main ${HOME}/ihaskell/main
COPY ihaskell/LICENSE ${HOME}/ihaskell/LICENSE

USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_UID}

RUN stack build && stack install

# Run the notebook
ENV PATH $(stack path --local-install-root)/bin:$(stack path --snapshot-install-root)/bin:$(stack path --compiler-bin):/home/${NB_USER}/.local/bin:${PATH}
RUN ihaskell install --stack
WORKDIR ${HOME}

ENV NOTEBOOK_DIR ${HOME}/notebooks
ENV NOTEBOOK_PW password
ENV NOTEBOOK_LOCATION hs
ENV PORT 8888

RUN mkdir ${NOTEBOOK_DIR}
COPY jupyter_write_passwd.py .
RUN ["python3", "jupyter_write_passwd.py"]

ENV NOTEBOOKARGS "--notebook-dir=${NOTEBOOK_DIR} --ip='*' \
				  --port=${PORT} --no-browser \
				  --config=${HOME}/.jupyter/jupyter_notebook_config.json"

CMD jupyter notebook ${NOTEBOOKARGS}
