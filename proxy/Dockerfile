FROM python:3.9-slim

RUN ["mkdir", "/proxy"]
WORKDIR /proxy

COPY supervisord.conf .

COPY requirements.txt .

RUN python -m pip install --upgrade pip

RUN --mount=type=cache,target=/root/.cache/pip \
        pip install -r requirements.txt

COPY server.py .

EXPOSE 8081
EXPOSE 1900/udp

RUN addgroup --gid 1001 --system app && \
    adduser --no-create-home --shell /bin/false --disabled-password --uid 1001 --system --group app

USER app

#ENV PYTHONUNBUFFERED=1
#HEALTHCHECK CMD curl --fail http://localhost:8081/1/login.aspx || exit 1 

CMD ["python", "server.py"]
