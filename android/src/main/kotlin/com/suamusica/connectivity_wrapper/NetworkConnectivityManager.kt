package com.suamusica.connectivity_wrapper

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build

class NetworkConnectivityManager(
    private val context: Context,
    private val onStatusChanged: ((ConnectivityStatus) -> Unit)? = null,
) {
    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var currentStatus: ConnectivityStatus = ConnectivityStatus.OFFLINE

    fun startMonitoring() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            emitStatus(checkCurrentStatus())
            return
        }

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onLost(network: Network) {
                emitStatus(checkCurrentStatus())
            }

            override fun onUnavailable() {
                emitStatus(ConnectivityStatus.OFFLINE)
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) {
                emitStatus(statusFromCapabilities(networkCapabilities))
            }
        }

        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback?.let {
            connectivityManager.registerNetworkCallback(networkRequest, it)
        }

        emitStatus(checkCurrentStatus())
    }

    fun stopMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            networkCallback?.let {
                try {
                    connectivityManager.unregisterNetworkCallback(it)
                } catch (_: Exception) {
                }
            }
            networkCallback = null
        }
    }

    private fun emitStatus(status: ConnectivityStatus) {
        if (currentStatus == status) return
        currentStatus = status
        onStatusChanged?.invoke(status)
    }

    private fun checkCurrentStatus(): ConnectivityStatus {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork ?: return ConnectivityStatus.OFFLINE
            val capabilities = connectivityManager.getNetworkCapabilities(network)
                ?: return ConnectivityStatus.OFFLINE
            statusFromCapabilities(capabilities)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            if (networkInfo?.isConnected == true) {
                ConnectivityStatus.ONLINE
            } else {
                ConnectivityStatus.OFFLINE
            }
        }
    }

    private fun statusFromCapabilities(capabilities: NetworkCapabilities): ConnectivityStatus {
        val validated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        if (validated) return ConnectivityStatus.ONLINE

        val captive = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
        val hasInternet =
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val hasTransport =
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)

        return if (captive || hasInternet || hasTransport) {
            ConnectivityStatus.LIMITED
        } else {
            ConnectivityStatus.OFFLINE
        }
    }

    fun currentStatus(): ConnectivityStatus = checkCurrentStatus()
}
