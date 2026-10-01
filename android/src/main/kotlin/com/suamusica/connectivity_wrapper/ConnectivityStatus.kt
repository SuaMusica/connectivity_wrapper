package com.suamusica.connectivity_wrapper

/**
 * - [OFFLINE] — sem rede.
 * - [LIMITED] — há transporte, mas sem internet validada (captive portal, etc.).
 * - [ONLINE] — internet validada ([NetworkCapabilities.NET_CAPABILITY_VALIDATED]).
 */
enum class ConnectivityStatus {
    OFFLINE,
    LIMITED,
    ONLINE,
}

internal fun ConnectivityStatus.toWire(): String = when (this) {
    ConnectivityStatus.OFFLINE -> "offline"
    ConnectivityStatus.LIMITED -> "limited"
    ConnectivityStatus.ONLINE -> "online"
}
