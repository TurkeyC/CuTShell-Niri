qml_module(celestia-internal
    URI Celestia.Internal
    SOURCES
        cachingimagemanager.hpp cachingimagemanager.cpp
        circularindicatormanager.hpp circularindicatormanager.cpp
        niriipc.hpp niriipc.cpp
        nirisocket.hpp nirisocket.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Network
)
