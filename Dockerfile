#
# Build:
#	docker build -f Dockerfile-cloud -t cloud-tpc .
#
FROM ubuntu-tpc

ENV DEBIAN_FRONTEND noninteractive

# install libraries and stuff, reconfigure system
RUN apt-get update; apt-get install -y -qq libfcgi-dev lighttpd sudo gdb pigz rsync postfix libopenblas-dev rsyslog
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && dpkg-reconfigure --frontend=noninteractive locales && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8 
ENV LC_ALL en_US.UTF-8

# Copy essential files
COPY main.cf /etc/postfix/main.cf
COPY sasl_passwd /etc/postfix/sasl/sasl_passwd
RUN postmap /etc/postfix/sasl/sasl_passwd
RUN chfn -f "Textpresso Central" root
COPY run.sh /root/run.sh
COPY run-cloud.sh /root/run-cloud.sh
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY cron* /usr/local/etc/

# Precompile system
COPY textpressocentral /data/textpresso/textpressocentral
COPY textpressoapi /data/textpresso/textpressoapi
COPY tpctools /data/textpresso/tpctools
RUN /root/run.sh -t \
&& rm -rf /data/textpresso/textpressocentral \
&& rm -rf /data/textpresso/textpressoapi \
&& rm -rf /data/textpresso/textpressoapi_data \
&& rm -rf /data/textpresso/tpctools

# essential files and dirs
WORKDIR /usr/local/textpresso
RUN ln -s ../uima_descriptors descriptors
RUN mkdir -p uti
RUN mkdir -p etc
COPY stopwords.postgres.tar.gz /usr/local/textpresso/etc/.
WORKDIR /

RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash Miniconda3-latest-Linux-x86_64.sh && rm Miniconda3-latest-Linux-x86_64.sh
ADD conda_env.yml conda_env.yml

RUN conda env create -f conda_env.yml
SHELL ["conda", "run", "-n", "agr_textpresso", "/bin/bash", "-c"]

ADD requirements.txt requirements.txt
RUN conda run -n agr_textpresso pip install -r requirements.txt


# start cron
RUN touch /var/log/cron.log && cron

CMD /root/run-cloud.sh
#    RUN:
#
#    see run_tpc_cloud.sh in this directory
