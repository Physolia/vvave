import QtQuick
import QtQml

import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

import org.mauikit.controls as Maui

import org.maui.vvave

import "../../utils/Player.js" as Player
import "../../db/Queries.js" as Q

import "../BabeTable"

Maui.Page
{
    id: control

    Maui.Theme.colorSet: Maui.Theme.Window

    property alias listModel: table.listModel
    readonly property alias listView : table.listView
    readonly property alias table: table

    readonly property alias contextMenu: table.contextMenu

    headBar.visible: false
    footBar.visible: !mainlistEmpty

    footBar.rightContent: ToolButton
    {
        icon.name: "edit-delete"
        onClicked:
        {
            player.stop()
            listModel.list.clear()
            root.sync = false
            root.syncPlaylist = ""
        }
    }

    footBar.leftContent: ToolButton
    {
        icon.name: "document-save"
        onClicked: saveList()
    }

    BabeTable
    {
        id: table
        anchors.fill: parent

        background: Rectangle
        {
            color: Maui.Theme.backgroundColor
            opacity: 0.2

            Behavior on color
            {
                Maui.ColorTransition{}
            }
        }

        Binding on currentIndex
        {
            value: currentTrackIndex
            restoreMode: Binding.RestoreBindingOrValue
        }

        listModel.sort: ""
        listBrowser.enableLassoSelection: false
        headBar.visible: false
        footBar.visible: false
        Maui.Theme.colorSet: Maui.Theme.Window

        holder.emoji: "qrc:/assets/view-media-track.svg"
        holder.title : "Nothing to play!"
        holder.body: i18n("Start putting together your playlist.")

        listView.header: Column
        {
            width: parent.width

            Loader
            {
                width: visible ? parent.width : 0
                height: width

                asynchronous: true
                active: !focusView && control.height > control.width*3 && currentTrackIndex >= 0
                visible: active
                sourceComponent: Item
                {
                    Maui.GalleryRollTemplate
                    {
                        anchors.fill: parent
                        anchors.bottomMargin: Maui.Style.space.medium
                        radius: Maui.Style.radiusV
                        interactive: true
                        fillMode: Image.PreserveAspectCrop

                        images: ["image://artwork/album:"+currentTrack.artist + ":"+ currentTrack.album, "image://artwork/artist:"+currentTrack.artist]
                    }

                   MouseArea
                   {
                       anchors.fill: parent
                       onDoubleClicked: toggleMiniMode()
                   }
                }
            }

            Rectangle
            {
                visible: root.sync
                Maui.Theme.inherit: false
                Maui.Theme.colorSet:Maui.Theme.Complementary
                z: table.z + 999
                width: parent.width
                height: visible ?  Maui.Style.rowHeightAlt : 0
                color: Maui.Theme.backgroundColor

                RowLayout
                {
                    anchors.fill: parent
                    anchors.leftMargin: Maui.Style.space.small

                    Label
                    {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        anchors.margins: Maui.Style.space.small
                        text: i18n("Syncing to ") + root.syncPlaylist
                    }

                    ToolButton
                    {
                        Layout.fillHeight: true
                        icon.name: "dialog-close"
                        onClicked:
                        {
                            root.sync = false
                            root.syncPlaylist = ""
                        }
                    }
                }
            }
        }

        delegate: TableDelegate
        {
            id: delegate

            width: ListView.view.width
            height: Math.max(implicitHeight, Maui.Style.rowHeight)
            appendButton: false

            property int mindex : index

            isCurrentItem: ListView.isCurrentItem
            mouseArea.drag.axis: Drag.YAxis
            Drag.source: delegate

            number : false
            coverArt : settings.showArtwork
            draggable: true
            checkable: false
            checked: false

            onPressAndHold: if(Maui.Handy.isTouch && table.allowMenu) table.openItemMenu(index)

            onRightClicked: tryOpenContextMenu()

            function tryOpenContextMenu()
            {
                if (table.allowMenu)
                    table.openItemMenu(index)
            }

            sameAlbum: control.totalMoves, evaluate(listModel.get(mindex-1))

            function evaluate(item)
            {
                return coverArt && item && item.album === model.album && item.artist === model.artist
            }

                Item
                {
                    visible: mindex === currentTrackIndex
                    Layout.fillHeight: true
                    Layout.preferredWidth: Maui.Style.rowHeight

                    AnimatedImage
                    {
                        id: _playingIcon
                        height: 16
                        width: height
                        playing: root.isPlaying && Maui.Style.enableEffects
                        anchors.centerIn: parent
                        source: "qrc:/assets/playing.gif"
                        visible: false
                    }

                    MultiEffect
                    {
                        anchors.fill: _playingIcon
                        source: _playingIcon
                        colorization: 1.0
                        contrast: 1.0
                        colorizationColor: "#fafafa"
                    }
                }

                AbstractButton
                {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Maui.Style.rowHeight
                    visible: (Maui.Handy.isTouch ? true : delegate.hovered) && index !== currentTrackIndex
                    icon.name: "edit-clear"
                    onClicked:
                    {
                        if(index === currentTrackIndex)
                            player.stop()

                        root.playlistManager.remove(index)
                    }

                    Maui.Icon
                    {
                        color: delegate.label1.color
                        anchors.centerIn: parent
                        height: Maui.Style.iconSizes.small
                        width: height
                        source: parent.icon.name
                    }
                    opacity: delegate.hovered ? 0.8 : 0.6
                }

                onClicked:
                {
                    table.forceActiveFocus()
                    if(Maui.Handy.isTouch)
                        Player.playAt(index)
                }

                onDoubleClicked:
                {
                    if(!Maui.Handy.isTouch)
                        Player.playAt(index)
                }


                onContentDropped: (drop) =>
                {
                    console.log("Move or insert ", drop.source.mindex)
                    if(typeof drop.source.mindex !== 'undefined')
                    {
                        console.log("Move ", drop.source.mindex,
                                    delegate.mindex)

                        root.playlistManager.move(drop.source.mindex, delegate.mindex)

                    }else
                    {
                        root.playlistManager.insert(String(drop.urls).split(","), delegate.mindex)
                    }

                    control.totalMoves++
                }
            }
        }

        property int totalMoves: 0

        function saveList()
        {
            var trackList = listModel.list.urls()
            if(listModel.list.count > 0)
            {
                _dialogLoader.sourceComponent = _playlistDialogComponent
                dialog.composerList.urls = trackList
                dialog.open()
            }
        }
    }
