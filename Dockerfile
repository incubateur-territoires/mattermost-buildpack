FROM scalingo/scalingo-22

WORKDIR /build
RUN mkdir /env /tmp/cache

COPY . .

RUN bin/env.sh .env /env
RUN bin/compile /build /tmp/cache /env
RUN rm -rf /app && mv /build /app 

WORKDIR /app

EXPOSE ${PORT}

ENTRYPOINT [ "/app/mattermost/bin/run" ]
