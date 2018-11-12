#!/usr/bin/env bash

oneMonthAgo=`date -d "-1 month" +%Y-%m-01`
oneMonthAgoTimestamp=`date -d $oneMonthAgo +%s`

baseUrl="https://registry.hub.docker.com/v2/repositories/library/golang/tags/?page="

processResult() {
  local result=$1

  version=`echo $result | grep alpine | sed -e 's/"//g'`

  if [ "$version" == "" ]; then
    return 0
  fi

  echo "Processing version: $version"

  dockerfileName="Dockerfile.$version.yml"
  sed "s/{VERSION}/$version/" Dockerfile.template.yml > $dockerfileName

  docker build -f $dockerfileName -t microlayers/golang-with-extras:$version .
  docker push microlayers/golang-with-extras:$version
  rm $dockerfileName

  return 0
}

page=0
while [ true ]; do
  page=$((page + 1))
  data=`curl -s $baseUrl$page`
  next=`echo $data|jq .next`
  index=0

  result=`echo $data|jq .results[$index].name`
  lastUpdated=`echo $data|jq .results[$index].last_updated | grep -Poe "\d{4}-\d{2}-\d{2}"`
  while [ "$result" != "null" ]; do
    timestamp=`date -d $lastUpdated +%s`
    if [ $oneMonthAgoTimestamp -gt $timestamp ]; then
      exit 0
    fi

    processResult $result

    index=$((index + 1))
    result=`echo $data|jq .results[$index].name`
    lastUpdated=`echo $data|jq .results[$index].last_updated | grep -Poe "\d{4}-\d{2}-\d{2}"`
  done

  if [ "$next" == "null" ] || [ $index -gt 10 ]; then
    break
  fi
done

