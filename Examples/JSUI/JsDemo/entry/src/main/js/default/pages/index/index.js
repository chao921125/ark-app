export default {
    data: {
        title: "",
        todayList: [
            {
                "event": "拿/获取",
                "tag": "urgent",
                "time": "12:30",
                "id": "eid1",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "约会/安排",
                "tag": "low",
                "time": "14:30",
                "id": "eid2",
                "checkBtn": "/common/done.png",
                "completeState": true,
                "showTag": "hide",
                "color": "text-gray"
            },
            {
                "event": "电子邮件",
                "tag": "middle",
                "time": "17:00",
                "id": "eid3",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "清除",
                "tag": "senior",
                "time": "22:00",
                "id": "eid4",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "购买",
                "tag": "senior",
                "time": "20:30",
                "id": "eid5",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "hide",
                "color": "text-default"
            },
            {
                "event": "拍摄",
                "tag": "middle",
                "time": "12:00",
                "id": "eid6",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "会议",
                "tag": "urgent",
                "time": "22:00",
                "id": "eid7",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "预约牙医",
                "tag": "low",
                "time": "20:30",
                "id": "eid8",
                "checkBtn": "/common/done.png",
                "completeState": true,
                "showTag": "hide",
                "color": "text-gray"
            },
            {
                "event": "与Alex吃午饭",
                "tag": "middle",
                "time": "12:00",
                "id": "eid9",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "线上演唱会",
                "tag": "senior",
                "time": "22:00",
                "id": "eid10",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            },
            {
                "event": "健身",
                "tag": "senior",
                "time": "8:30",
                "id": "eid11",
                "checkBtn": "/common/checkbutton.png",
                "completeState": false,
                "showTag": "show",
                "color": "text-default"
            }
        ]
    },
    onInit() {
        this.title = this.$t('strings.world');
    },
    completeEvent(e) {
        for (var i of this.todayList) {
            if (i.id == e) {
                if (i.checkBtn == "/common/done.png") {
                    i.checkBtn = "/common/checkbutton.png";
                    i.showTag = 'show';
                    i.color = 'text-default';
                    i.completeState = false;
                } else {
                    i.checkBtn = "/common/done.png";
                    i.showTag = 'hide';
                    i.color = 'text-gray';
                    i.completeState = true;
                }
                return;
            }
        }
    },
    deleteEvent: function (e) {
        for (var i in this.todayList) {
            if (this.todayList[i].id == e) {
                this.todayList.splice(i, 1);
                return;
            }
        }
    }
}
