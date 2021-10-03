import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Window 2.15

import Qt.labs.settings 1.0

import org.kde.kirigami 2.7 as Kirigami
import org.mauikit.controls 1.3 as Maui
import org.mauikit.filebrowsing 1.3 as FB
import org.mauikit.accounts 1.0 as MA

import org.maui.vvave 1.0

import "widgets"
import "widgets/PlaylistsView"
import "widgets/MainPlaylist"
import "widgets/SettingsView"
import "widgets/CloudView"
import "widgets/FoldersView"

import "utils/Player.js" as Player

Maui.ApplicationWindow
{
    id: root
    title: currentTrack.url ? currentTrack.title + " - " +  currentTrack.artist + " | " + currentTrack.album : ""
    headBar.visible: false

    //    flags: miniMode ? Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint | Qt.Popup | Qt.BypassWindowManagerHint : undefined

    readonly property int preferredMiniModeSize: 200
    minimumHeight: miniMode ? preferredMiniModeSize : 0
    minimumWidth: miniMode ? preferredMiniModeSize : 0

    maximumWidth: miniMode ? minimumWidth : Screen.desktopAvailableWidth
    maximumHeight: miniMode ? minimumHeight : Screen.desktopAvailableHeight

    /***************************************************/
    /******************** ALIASES ********************/
    /*************************************************/
    property alias selectionBar: _selectionBarLoader.item
    property alias dialog : _dialogLoader.item

    /***************************************************/
    /******************** PLAYBACK ********************/
    /*************************************************/
    readonly property alias currentTrack : playlist.currentTrack
    property alias currentTrackIndex: playlist.currentIndex

    readonly property string progressTimeLabel: player.transformTime((player.duration/1000) * (player.pos/player.duration))
    readonly property string durationTimeLabel: player.transformTime((player.duration/1000))

    readonly property alias isPlaying: player.playing
    property int onQueue: 0
    property alias mainPlaylist : _mainPlaylistLoader.item
    readonly property bool mainlistEmpty: mainPlaylist.listModel.list.count ===0

    /***************************************************/
    /******************** HANDLERS ********************/
    /*************************************************/
    readonly property var viewsIndex: ({ tracks: 0,
                                           albums: 1,
                                           artists: 2,
                                           playlists: 3,
                                           folders: 4,
                                           cloud: 5 })

    property string syncPlaylist: ""
    property bool sync: false

    readonly property bool focusView : _focusViewComponent.visible
    readonly property bool miniMode : _miniModeComponent.visible

    property bool selectionMode : false

    /***************************************************/
    /******************** UI COLORS *******************/
    /*************************************************/
    readonly property color babeColor: "#f84172"


    /*HANDLE EVENTS*/
    onClosing: Player.savePlaylist()

    //    Maui.WindowBlur
    //    {
    //        view: root
    //        geometry: Qt.rect(root.x, root.y, root.width, root.height)
    //        windowRadius: root.background.radius
    //        enabled: !Kirigami.Settings.isMobile
    //    }

    Loader
    {
        asynchronous: true
        FloatingDisk {}
    }

    Settings
    {
        id: settings
        category: "Settings"
        property bool fetchArtwork: true
        property bool autoScan: true
    }

    Mpris2
    {
        playListModel: playlist
        audioPlayer: player
        playerName: 'vvave'

        onRaisePlayer:
        {
            root.raise()
        }
    }

    Playlist
    {
        id: playlist
        model: mainPlaylist.listModel.list
        onCurrentTrackChanged: Player.playTrack()

        onMissingFile:
        {
            var message = i18n("Missing file")
            var messageBody = track.title + " by " + track.artist + " is missing.\nDo you want to remove it from your collection?"
            notify("dialog-question", message, messageBody, function ()
            {
                console.log("REMOVE TIU MSISING")
                mainPlaylist.table.list.remove(mainPlaylist.table.currentIndex)
                console.log("REMOVE TIU MSISING 2")
            })
        }
    }

    Player
    {
        id: player
        volume: 100
        onFinished:
        {
            if (!mainlistEmpty)
            {
                if (currentTrack && currentTrack.url)
                    mainPlaylist.listModel.list.countUp(currentTrackIndex)

                Player.nextTrack()
            }
        }
    }

    Loader
    {
        id: _dialogLoader
    }

    Component
    {
        id: _fileDialogComponent
        FB.FileDialog {}
    }

    Component
    {
        id: _settingsDialogComponent
        SettingsDialog {}
    }

    Component
    {
        id: _removeDialogComponent

        Maui.FileListingDialog
        {
            id: _removeDialog

            urls: selectionBar.uris

            title: i18n("Remove %1 tracks", urls.length)
            message: i18n("Are you sure you want to remove this files? This action can not be undone.")

            rejectButton.text: i18n("Delete")
            acceptButton.text: i18n("Cancel")

            onAccepted: close()

            onRejected:
            {
                FB.FM.removeFiles(_removeDialog.urls)
                close()
            }
        }
    }

    Component
    {
        id: _playlistDialogComponent

        FB.TagsDialog
        {
            onTagsReady: composerList.updateToUrls(tags)
            composerList.strict: false
        }
    }

    sideBar: Maui.AbstractSideBar
    {
        id: _drawer
        visible: true
        preferredWidth: Kirigami.Units.gridUnit * 18
        collapsed : root.width < preferredWidth * 2
        collapsible: true

        onContentDropped:
        {
            if(drop.urls)
            {
                var urls = drop.urls.join(",")
                Vvave.openUrls(urls.split(","))
            }
        }

        background: null
        Loader
        {            id: _mainPlaylistLoader
            anchors.fill: parent

            asynchronous: true
            sourceComponent: MainPlaylist
            {
            }
        }
    }

    footer: Loader
    {
        asynchronous: true
        width: parent.width
        visible: _viewsPage.visible

        sourceComponent: PlaybackBar {}
    }

    StackView
    {
        id: _stackView
        focus: true
        anchors.fill: parent

        initialItem: Item
        {
            id: _viewsPage

            Maui.AppViews
            {
                id: swipeView
                anchors.fill: parent
                maxViews: 3
                interactive: Kirigami.Settings.isMobile
                floatingFooter: true
                flickable: swipeView.currentItem.flickable || swipeView.currentItem.item.flickable
                altHeader: Kirigami.Settings.isMobile
                showCSDControls: true

                headBar.leftContent: Loader
                {
                    asynchronous: true

                    sourceComponent: Maui.ToolButtonMenu
                    {
                        icon.name: "application-menu"

                        MA.AccountsMenuItem{}

                        MenuItem
                        {
                            text: i18n("Settings")
                            icon.name: "settings-configure"
                            onTriggered:
                            {
                                _dialogLoader.sourceComponent = _settingsDialogComponent
                                dialog.open()
                            }
                        }

                        MenuItem
                        {
                            text: i18n("About")
                            icon.name: "documentinfo"
                            onTriggered: root.about()
                        }
                    }
                }

                footer: Loader
                {
                    id: _selectionBarLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width-(Maui.Style.space.medium*2), item.implicitWidth)
                    asynchronous: true

                    sourceComponent: SelectionBar
                    {
                        padding: Maui.Style.space.big
                        maxListHeight: swipeView.height - Maui.Style.space.medium
                        display: ToolButton.IconOnly

                        onExitClicked:
                        {
                            root.selectionMode = false
                            clear()
                        }
                    }
                }

                Maui.AppViewLoader
                {
                    Maui.AppView.title: i18n("Songs")
                    Maui.AppView.iconName: "view-media-track"

                    TracksView {}
                }

                Maui.AppViewLoader
                {
                    Maui.AppView.title: i18n("Albums")
                    Maui.AppView.iconName: "view-media-album-cover"

                    AlbumsView
                    {
                        holder.title : i18n("No Albums!")
                        holder.body: i18n("Add new music sources")
                        list.query: Albums.ALBUMS
                    }
                }

                Maui.AppViewLoader
                {
                    Maui.AppView.title: i18n("Artists")
                    Maui.AppView.iconName: "view-media-artist"

                    AlbumsView
                    {
                        holder.title : i18n("No Artists!")
                        holder.body: i18n("Add new music sources")
                        list.query : Albums.ARTISTS
                    }
                }

                Maui.AppViewLoader
                {
                    Maui.AppView.title: i18n("Tags")
                    Maui.AppView.iconName: "tag"
                    PlaylistsView {}
                }

                Maui.AppViewLoader
                {
                    Maui.AppView.title: i18n("Folders")
                    Maui.AppView.iconName: "folder"

                    FoldersView {}
                }

                Maui.AppViewLoader
                {
                    Maui.AppView.title: i18n("Cloud")
                    Maui.AppView.iconName: "folder-cloud"

                    CloudView {}
                }
            }

            Maui.ProgressIndicator
            {
                width: parent.width
                anchors.bottom: parent.bottom
                visible: Vvave.scanning
            }
        }

        Loader
        {
            id: _focusViewComponent
            visible: StackView.status === StackView.Active
            active: StackView.status === StackView.Active || item

            FocusView
            {
                anchors.fill: parent
            }
        }

        Loader
        {
            id: _miniModeComponent
            visible: active
            active: StackView.status === StackView.Active
            MiniMode
            {
                anchors.fill: parent
            }
        }
    }

    Component.onCompleted:
    {
        Vvave.autoScan = settings.autoScan
        Vvave.fetchArtwork = settings.fetchArtwork

        if(Maui.Handy.isAndroid)
        {
            Maui.Android.statusbarColor(headBar.Kirigami.Theme.backgroundColor, false)
            Maui.Android.navBarColor(headBar.visible ? headBar.Kirigami.Theme.backgroundColor : Kirigami.Theme.backgroundColor, false)
        }
    }

    /*CONNECTIONS*/
    Connections
    {
        target: Vvave
        ignoreUnknownSignals: true
        function onOpenFiles(tracks)
        {
            Player.appendTracksAt(tracks, 0)
            Player.playAt(0)
        }
    }

    function toggleFocusView()
    {
        if(focusView)
        {
            _stackView.pop(StackView.Immediate)
            _stackView.currentItem.forceActiveFocus()
        }else
        {
            _stackView.push(_focusViewComponent, StackView.Immediate)
            _focusViewComponent.forceActiveFocus()
        }
    }

    property int oldH : root. height
    property int oldW : root.width
    property point oldP : Qt.point(root.x, root.y)

    function toggleMiniMode()
    {
        if(miniMode)
        {
            _stackView.pop(StackView.Immediate)

            root.width = oldW
            root.height = oldH

            root.x = oldP.x
            root.y = oldP.y
        }else
        {
            root.oldH = root.height
            root.oldW = root.width
            root.oldP = Qt.point(root.x, root.y)

            _stackView.push(_miniModeComponent, StackView.Immediate)

            root.x = Screen.desktopAvailableWidth - root.preferredMiniModeSize - Maui.Style.space.big
            root.y = Screen.desktopAvailableHeight - root.preferredMiniModeSize - Maui.Style.space.big
        }
    }
}
