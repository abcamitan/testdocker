FROM mcr.microsoft.com/dotnet/sdk:5.0-buster-slim as dotnet-build
WORKDIR /usr/src
COPY . /usr/src

RUN dotnet restore "testdocker.csproj"
RUN dotnet build "testdocker.csproj" -c Release -o /app/build

FROM dotnet-build AS dotnet-publish
RUN dotnet publish "testdocker.csproj" -c Release -o /app/publish

FROM node:16.5-buster-slim as node_base
RUN mkdir /usr/src/app
WORKDIR /usr/src/app
ENV NODE_ENV=production
ENV PATH /usr/src/app/node_modules/.bin:$PATH
COPY ClientApp/. /usr/src/app
RUN npm install
RUN npm run build

FROM mcr.microsoft.com/dotnet/aspnet:5.0-buster-slim as final
WORKDIR /usr/publish
EXPOSE 80
EXPOSE 443
COPY --from=dotnet-publish /app/publish .
COPY --from=node_base /usr/src/app/build /usr/publish/ClientApp/build
ENTRYPOINT [ "dotnet" , "testdocker.dll" ]
