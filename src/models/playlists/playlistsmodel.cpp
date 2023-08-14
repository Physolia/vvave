#include "playlistsmodel.h"
#include "db/collectionDB.h"

#include <QDateTime>

#include <MauiKit3/FileBrowsing/fmstatic.h>
#include <MauiKit3/FileBrowsing/tagging.h>

#include <KI18n/KLocalizedString>

PlaylistsModel::PlaylistsModel(QObject *parent)
    : MauiList(parent)
{
    connect(Tagging::getInstance(), &Tagging::tagged, [this](QVariantMap tag) {
        emit this->preItemAppended();
        this->list << (this->packPlaylist(tag.value("tag").toString()));
        emit this->postItemAppended();
    });

    connect(Tagging::getInstance(), &Tagging::urlTagged, [this](QUrl, QString tag) {
        const auto index = this->indexOf(FMH::MODEL_KEY::PLAYLIST, tag);
        auto item = this->list[index];
        item[FMH::MODEL_KEY::PREVIEW] = playlistArtworkPreviews(tag);
        this->list[index] = item;
        emit this->updateModel(index, {});
    });
}

const FMH::MODEL_LIST &PlaylistsModel::items() const
{
    return this->list;
}

void PlaylistsModel::setList()
{
    emit this->preListChanged();
    if(m_limit == 9999)
    {
        this->list << this->defaultPlaylists();
    }
    this->list << this->tags();
    emit this->postListChanged();
}

FMH::MODEL PlaylistsModel::packPlaylist(const QString &playlist)
{
    return FMH::MODEL{
        {FMH::MODEL_KEY::KEY, playlist},
        {FMH::MODEL_KEY::PLAYLIST, playlist},
        {FMH::MODEL_KEY::ICON, "tag"},
        {FMH::MODEL_KEY::TYPE, "personal"},
        {FMH::MODEL_KEY::PREVIEW, playlistArtworkPreviews(playlist)}};
}

QString PlaylistsModel::playlistArtworkPreviews(const QString &playlist)
{
    QStringList res;

    auto extractor = [&res](FMH::MODEL &item) -> bool
    {
        res << QString("image://artwork/album:%1:%2").arg(item[FMH::MODEL_KEY::ARTIST], item[FMH::MODEL_KEY::ALBUM]);
        return true;
    };

    if (playlist == "mostPlayed") {
      CollectionDB::getInstance()->getDBData(QString("select t.* from tracks t inner join albums al on t.album = al.album and t.artist = al.artist WHERE t.count >= 3 order by strftime(\"%s\", t.addDate) desc, t.count asc LIMIT 4"), extractor);

        return res.join(",");
    }

    if (playlist == "randomTracks") {
      CollectionDB::getInstance()->getDBData(QString("select t.* from tracks t inner join albums al on t.album = al.album and t.artist = al.artist where t.count <= 4 order by  RANDOM()"), extractor);

        return res.join(",");
    }

    if (playlist == "recentTracks") {
      CollectionDB::getInstance()->getDBData(QString("select t.* from (select * from tracks order by strftime(\"%s\", lastsync) desc limit 10) t inner join albums al on t.album = al.album and t.artist = al.artist order by t.title asc LIMIT 4"), extractor);

        return res.join(",");
    }

    if (playlist == "neverPlayed") {
      CollectionDB::getInstance()->getDBData(QString("select t.* from tracks t inner join albums al on t.album = al.album and t.artist = al.artist where t.count <= 1 order by RANDOM()"), extractor);

        return res.join(",");
    }

    if (playlist == "classicTracks") {
      CollectionDB::getInstance()->getDBData(QString("select t.* from (select * from tracks where releasedate > 0 order by releasedate asc limit 100) t inner join albums al on t.album = al.album and t.artist = al.artist order by t.title asc LIMIT 4"), extractor);

        return res.join(",");
    }

    const auto urls = Tagging::getInstance()->getTagUrls(playlist, {}, true, 4, "audio");
    for (const auto &url : urls) {
        const auto data = CollectionDB::getInstance()->getDBData(QString("select t.* from tracks t inner join albums al on al.album = t.album and al.artist = t.artist where t.url = %1").arg("\"" + url.toString() + "\""));

        for (const auto &item : data) {
            res << QString("image://artwork/album:%1:%2").arg(item[FMH::MODEL_KEY::ARTIST], item[FMH::MODEL_KEY::ALBUM]);
        }
    }

    return res.join(",");
}

FMH::MODEL_LIST PlaylistsModel::defaultPlaylists()
{
    const FMH::MODEL mostPlayed =  {{FMH::MODEL_KEY::TYPE, "default"},
                              {FMH::MODEL_KEY::PLAYLIST, i18n("Most Played")},
                              {FMH::MODEL_KEY::KEY, "mostPlayed"},
                              {FMH::MODEL_KEY::PREVIEW, playlistArtworkPreviews("mostPlayed")},
                              {FMH::MODEL_KEY::ICON, "view-media-playcount"},
                              {FMH::MODEL_KEY::ADDDATE, QDateTime::currentDateTime().toString(Qt::DateFormat::TextDate)}};

    const FMH::MODEL randomTracks =  {{FMH::MODEL_KEY::TYPE, "default"},
                                {FMH::MODEL_KEY::PLAYLIST, i18n("Random Tracks")},
                                {FMH::MODEL_KEY::KEY, "randomTracks"},
                                {FMH::MODEL_KEY::PREVIEW, playlistArtworkPreviews("randomTracks")},
                                {FMH::MODEL_KEY::ICON, "view-media-playcount"},
                                {FMH::MODEL_KEY::ADDDATE, QDateTime::currentDateTime().toString(Qt::DateFormat::TextDate)}};

   const FMH::MODEL recentTracks =  {{FMH::MODEL_KEY::TYPE, "default"},
                                {FMH::MODEL_KEY::PLAYLIST, i18n("Recent Tracks")},
                                {FMH::MODEL_KEY::KEY, "recentTracks"},
                                {FMH::MODEL_KEY::PREVIEW, playlistArtworkPreviews("recentTracks")},
                                {FMH::MODEL_KEY::ICON, "view-media-playcount"},
                                {FMH::MODEL_KEY::ADDDATE, QDateTime::currentDateTime().toString(Qt::DateFormat::TextDate)}};

   const FMH::MODEL neverPlayed =  {{FMH::MODEL_KEY::TYPE, "default"},
                               {FMH::MODEL_KEY::PLAYLIST, i18n("Never Played")},
                               {FMH::MODEL_KEY::KEY, "neverPlayed"},
                               {FMH::MODEL_KEY::PREVIEW, playlistArtworkPreviews("neverPlayed")},
                               {FMH::MODEL_KEY::ICON, "view-media-playcount"},
                               {FMH::MODEL_KEY::ADDDATE, QDateTime::currentDateTime().toString(Qt::DateFormat::TextDate)}};

   const FMH::MODEL classicTracks =  {{FMH::MODEL_KEY::TYPE, "default"},
                                 {FMH::MODEL_KEY::PLAYLIST, i18n("Classic Tracks")},
                                 {FMH::MODEL_KEY::KEY, "classicTracks"},
                                 {FMH::MODEL_KEY::PREVIEW, playlistArtworkPreviews("classicTracks")},
                                 {FMH::MODEL_KEY::ICON, "view-media-playcount"},
                                 {FMH::MODEL_KEY::ADDDATE, QDateTime::currentDateTime().toString(Qt::DateFormat::TextDate)}};

    return FMH::MODEL_LIST () << mostPlayed << randomTracks << recentTracks << neverPlayed << classicTracks;
}

FMH::MODEL_LIST PlaylistsModel::tags()
{
    FMH::MODEL_LIST res;
    const auto tags = Tagging::getInstance()->getUrlsTags(true);

    return std::accumulate(tags.constBegin(), tags.constEnd(), res, [this](FMH::MODEL_LIST &list, const QVariant &item) {

        const auto map = item.toMap();

        auto res = packPlaylist(map.value("tag").toString());

        res[FMH::MODEL_KEY::ICON] = map.value("icon").toString();

        if(list.count() <= m_limit)
        {
            list << res;
        }
        return list;
    });
}

void PlaylistsModel::insert(const QString &playlist)
{
    if (playlist.isEmpty())
        return;

    Tagging::getInstance()->tag(playlist);
}

void PlaylistsModel::addTrack(const QString &playlist, const QStringList &urls)
{
    for (const auto &url : urls)
        Tagging::getInstance()->tagUrl(url, playlist);
}

void PlaylistsModel::removeTrack(const QString &playlist, const QString &url)
{
    qDebug() << "trying to remove" << playlist << url;
    Tagging::getInstance()->removeUrlTag(url, playlist);
}

void PlaylistsModel::removePlaylist(const int &index) // TODO
{
    if (index >= this->list.size() || index < 0)
    {
        return;
    }

    if(Tagging::getInstance()->removeTag(this->list.at(index)[FMH::MODEL_KEY::PLAYLIST], true))
    {
        emit this->preItemRemoved(index);
        this->list.removeAt(index);
        emit this->postItemRemoved();
    }
}

void PlaylistsModel::componentComplete()
{
    this->setList();
}

int PlaylistsModel::limit() const
{
    return m_limit;
}

void PlaylistsModel::setLimit(int newLimit)
{
    if (m_limit == newLimit)
        return;
    m_limit = newLimit;
    emit limitChanged();
}
