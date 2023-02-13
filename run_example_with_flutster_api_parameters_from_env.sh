#!/bin/bash
if [[ -z "${SEARCHCHOICESFLUTSTERKEY}" ]]; then
	export SEARCHCHOICESFLUTSTERKEY=${{ secrets.FLUTSTERAPIKEY }}
fi
if [[ -z "${SEARCHCHOICESFLUTSTERUSER}" ]]; then
        export SEARCHCHOICESFLUTSTERUSER=${{ secrets.FLUTSTERAPIUSER }}
fi
if [[ -z "${SEARCHCHOICESFLUTSTERURL}" ]]; then
        export SEARCHCHOICESFLUTSTERURL=${{ secrets.FLUTSTERAPIURL }}
fi

pushd example
flutter run --dart-define="flutsterKey=$SEARCHCHOICESFLUTSTERKEY" --dart-define="flutsterUser=$SEARCHCHOICESFLUTSTERUSER" --dart-define="flutsterUrl=$SEARCHCHOICESFLUTSTERURL"
popd
