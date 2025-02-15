/*
    Copyright © 2020-2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module creator.actions.node;
import creator.core.actionstack;
import creator.actions;
import creator;
import inochi2d;
import std.format;
import i18n;
import std.exception;
import std.array: insertInPlace;
import std.algorithm.mutation: remove;

/**
    An action that happens when a node is changed
*/
class NodeMoveAction : Action {
public:

    /**
        Descriptive name
    */
    string descrName;
    
    /**
        Which index in to the parent the nodes should be placed
    */
    size_t parentOffset;
    float[uint] zSort;

    /**
        Previous parent of node
    */
    Node[uint] prevParents;
    size_t[uint] prevOffsets;

    /**
        Nodes that was moved
    */
    Node[] nodes;

    /**
        New parent of node
    */
    Node newParent;

    /**
        The original transform of the node
    */
    Transform[uint] originalTransform;

    /**
        The new transform of the node
    */
    Transform[uint] newTransform;

    /**
        Creates a new node change action
    */
    this(Node[] nodes, Node new_, size_t pOffset = 0) {
        this.newParent = new_;
        this.nodes = nodes;
        this.parentOffset = pOffset;

        // Enforce reparenting rules
        foreach(sn; nodes) enforce(sn.canReparent(new_), _("%s can not be reparented in to %s due to a circular dependency.").format(sn.name, new_.name));
        
        // Reparent
        foreach(ref sn; nodes) {
            
            // Store ref to prev parent
            if (sn.parent) {
                originalTransform[sn.uuid] = sn.localTransform;
                prevParents[sn.uuid] = sn.parent;
                prevOffsets[sn.uuid] = sn.getIndexInParent();
                zSort[sn.uuid] = sn.zSort;
            }

            // Set relative position
            if (new_) {
                sn.reparent(new_, pOffset);
                sn.transformChanged();
            } else sn.parent = null;
            newTransform[sn.uuid] = sn.localTransform;
        }
        incActivePuppet().rescanNodes();
    
        // Set visual name
        if (nodes.length == 1) descrName = nodes[0].name;
        else descrName = _("nodes");
    }

    /**
        Rollback
    */
    void rollback() {
        foreach(ref sn; nodes) {
            if (sn.uuid in prevParents && prevParents[sn.uuid]) {
                if (!sn.lockToRoot()) sn.setRelativeTo(prevParents[sn.uuid]);
                sn.reparent(prevParents[sn.uuid], prevOffsets[sn.uuid]);
                if (sn.uuid in zSort) {
                    sn.zSort = zSort[sn.uuid] - prevParents[sn.uuid].zSort();
                }
                sn.localTransform = originalTransform[sn.uuid];
                sn.transformChanged();
            } else sn.parent = null;
        }
        incActivePuppet().rescanNodes();
    }

    /**
        Redo
    */
    void redo() {
        foreach(sn; nodes) {
            if (newParent) {
                if (!sn.lockToRoot()) sn.setRelativeTo(newParent);
                sn.reparent(newParent, parentOffset);
                sn.localTransform = newTransform[sn.uuid];
                sn.transformChanged();
            } else sn.parent = null;
        }
        incActivePuppet().rescanNodes();
    }

    /**
        Describe the action
    */
    string describe() {
        if (prevParents.length == 0) return _("Created %s").format(descrName);
        if (newParent is null) return _("Deleted %s").format(descrName);
        return _("Moved %s to %s").format(descrName, newParent.name);
    }

    /**
        Describe the action
    */
    string describeUndo() {
        if (prevParents.length == 0) return _("Created %s").format(descrName);
        if (nodes.length == 1 && prevParents.length == 1 && prevParents.values[0]) return  _("Moved %s from %s").format(descrName, prevParents[nodes[0].uuid].name);
        return _("Moved %s from origin").format(descrName);
    }

    /**
        Gets name of this action
    */
    string getName() {
        return this.stringof;
    }
    
    bool merge(Action other) { return false; }
    bool canMerge(Action other) { return false; }
}

/**
    An action that happens when a node is changed
*/
class PartAddRemoveMaskAction(bool addAction = false) : Action {
public:

    /**
        Previous parent of node
    */
    Part target;
    MaskingMode mode;
    size_t offset;
    Drawable maskSrc;

    /**
        Creates a new node change action
    */
    this(Drawable drawable, Part target, MaskingMode mode) {
        this.maskSrc = drawable;
        this.target = target;

        if (addAction) {
            offset = target.masks.length;
            target.masks ~= MaskBinding(maskSrc.uuid, mode, drawable);

        } else {
            foreach (i, masker; target.masks) {
                if (masker.maskSrc == maskSrc) {
                    offset = i;
                    target.masks = target.masks.remove(i);
                    break;
                }
            }
        }
        incActivePuppet().rescanNodes();
    }

    /**
        Rollback
    */
    void rollback() {
        if (addAction) {
            target.masks = target.masks.remove(offset);
        } else {
            target.masks.insertInPlace(offset, MaskBinding(maskSrc.uuid, mode, maskSrc));
        }
        incActivePuppet().rescanNodes();
    }

    /**
        Redo
    */
    void redo() {
        if (addAction) {
            target.masks.insertInPlace(offset, MaskBinding(maskSrc.uuid, mode, maskSrc));
        } else {
            target.masks = target.masks.remove(offset);
        }
        incActivePuppet().rescanNodes();
    }

    /**
        Describe the action
    */
    string describe() {
        if (addAction) return _("%s is added to mask of %s").format(maskSrc.name, target.name);
        else return _("%s is deleted from mask of %s").format(maskSrc.name, target.name);
    }

    /**
        Describe the action
    */
    string describeUndo() {
        if (addAction) return _("%s is deleted from mask of %s").format(maskSrc.name, target.name);
        else return _("%s is added to mask of %s").format(maskSrc.name, target.name);
    }

    /**
        Gets name of this action
    */
    string getName() {
        return this.stringof;
    }
    
    bool merge(Action other) { return false; }
    bool canMerge(Action other) { return false; }
}

alias PartAddMaskAction = PartAddRemoveMaskAction!true;
alias PartRemoveMaskAction = PartAddRemoveMaskAction!false;

/**
    Action for whether a node was activated or deactivated
*/
class NodeActiveAction : Action {
public:
    Node self;
    bool newState;

    /**
        Rollback
    */
    void rollback() {
        self.enabled = !newState;
    }

    /**
        Redo
    */
    void redo() {
        self.enabled = newState;
    }

    /**
        Describe the action
    */
    string describe() {
        return "%s %s".format(newState ? _("Enabled") : _("Disabled"), self.name);
    }

    /**
        Describe the action
    */
    string describeUndo() {
        return _("%s was %s").format(self.name, !newState ? _("Enabled") : _("Disabled"));
    }

    /**
        Gets name of this action
    */
    string getName() {
        return this.stringof;
    }
    
    bool merge(Action other) { return false; }
    bool canMerge(Action other) { return false; }
}

/**
    Moves multiple children with history
*/
void incMoveChildrenWithHistory(Node[] n, Node to, size_t offset) {
    // Push action to stack
    incActionPush(new NodeMoveAction(
        n,
        to,
        offset
    ));
}

/**
    Moves child with history
*/
void incMoveChildWithHistory(Node n, Node to, size_t offset) {
    incMoveChildrenWithHistory([n], to, offset);
}

/**
    Adds child with history
*/
void incAddChildWithHistory(Node n, Node to, string name=null) {
    if (to is null) to = incActivePuppet().root;

    // Push action to stack
    incActionPush(new NodeMoveAction(
        [n],
        to
    ));

    n.insertInto(to, Node.OFFSET_START);
    n.localTransform.clear();
    if (name is null) n.name = _("Unnamed ")~_(n.typeId());
    else n.name = name;
    incActivePuppet().rescanNodes();
}

Node recursiveDuplicate(Node n){
    Node x;
    if (cast(Part) n) {
        Part c = cast(Part) n;
        Part p = new Part(c.getMesh(),c.textures); 
        p.textureIds = c.textureIds;
        p.tint = c.tint;
        p.screenTint = c.screenTint;
        p.emissionStrength = c.emissionStrength;
        p.blendingMode = c.blendingMode;
        p.opacity = c.opacity;
        p.maskAlphaThreshold = c.maskAlphaThreshold;
        p.masks = c.masks;
        x = p;
    } else if (cast(Composite) n) {
        //Do Composites hold any unique data?
        Composite c = cast(Composite)n;
        Composite p = new Composite(null);
        p.tint = c.tint;
        p.screenTint = c.screenTint;
        p.blendingMode = c.blendingMode;
        p.opacity = c.opacity;
        p.threshold = c.threshold;
        p.masks = c.masks;
        x = p;    
    } else if (cast(MeshGroup) n) {
        //Do meshgroups hold into any unique data?
        MeshGroup p = new MeshGroup(null);
        x = p;
    } else if (cast(SimplePhysics) n) {
        SimplePhysics c = cast(SimplePhysics) n;
        SimplePhysics p = new SimplePhysics(null);
        p.param(c.param());
        p.modelType_ = c.modelType_;
        p.mapMode = c.mapMode;
        p.localOnly = c.localOnly;
        p.gravity = c.gravity;
        p.length = c.length;
        p.frequency = c.frequency;
        p.angleDamping = c.angleDamping;
        p.lengthDamping = c.lengthDamping;
        p.outputScale = c.outputScale;
        p.output = c.output;
        x = p;
    } else if (cast(Camera) n) {
        //Lets not duplicate cameras for now
        return null; 
    } else x = new Node(inCreateUUID(),null);    
    //Applies to all node types
    x.name = n.name;
    x.enabled = n.enabled;
    x.globalTransform = n.globalTransform;
    x.localTransform = n.localTransform;
    x.zSort = n.zSort;
    foreach (child; n.children()) {
        x.addChild(recursiveDuplicate(child));
    }
    return x; 
}

GroupAction incDeleteMaskOfNode(Node n, GroupAction group = null) {
    auto removedDrawables = incActivePuppet().findNodesType!Drawable(n);
    auto parts = incActivePuppet().findNodesType!Part(incActivePuppet().root);
    foreach (drawable; removedDrawables) {
        foreach (target; parts) {
            auto idx = target.getMaskIdx(drawable);
            if (idx >= 0) {
                if (group is null)
                    group = new GroupAction();
                group.addAction(new PartRemoveMaskAction(drawable, target, target.masks[idx].mode));
            }
        }
    }
    return group;
}

/**
    Deletes child with history
*/
void incDeleteChildWithHistory(Node n) {
    auto group = incDeleteMaskOfNode(n);
    if (group !is null) {
        group.addAction(new NodeMoveAction(
            [n],
            null
        ));
        incActionPush(group);
    } else {
        // Push action to stack
        incActionPush(new NodeMoveAction(
            [n],
            null
        ));
    }
    
    incActivePuppet().rescanNodes();
}

/**
    Deletes child with history
*/
void incDeleteChildrenWithHistory(Node[] ns) {
    GroupAction group = null;
    foreach (n; ns) {
        incDeleteMaskOfNode(n, group);
    }
    if (group !is null) {
        // Push action to stack
        group.addAction(new NodeMoveAction(
            ns,
            null
        ));
        incActionPush(group);
    } else {
        // Push action to stack
        incActionPush(new NodeMoveAction(
            ns,
            null
        ));
    }

    incActivePuppet().rescanNodes();
}

/**
    Node value changed action
*/
class NodeValueChangeAction(TNode, T) : Action if (is(TNode : Node)) {
public:
    alias TSelf = typeof(this);
    TNode node;
    T oldValue;
    T newValue;
    T* valuePtr;
    string name;

    this(string name, TNode node, T oldValue, T newValue, T* valuePtr) {
        this.name = name;
        this.node = node;
        this.oldValue = oldValue;
        this.newValue = newValue;
        this.valuePtr = valuePtr;
    }

    /**
        Rollback
    */
    void rollback() {
        *valuePtr = oldValue;
    }

    /**
        Redo
    */
    void redo() {
        *valuePtr = newValue;
    }

    /**
        Describe the action
    */
    string describe() {
        return _("%s->%s changed to %s").format(node.name, name, newValue);
    }

    /**
        Describe the action
    */
    string describeUndo() {
        return _("%s->%s changed from %s").format(node.name, name, oldValue);
    }

    /**
        Gets name of this action
    */
    string getName() {
        return name;
    }
    
    /**
        Merge
    */
    bool merge(Action other) {
        if (this.canMerge(other)) {
            this.newValue = (cast(TSelf)other).newValue;
            return true;
        }
        return false;
    }

    /**
        Gets whether this node can merge with an other
    */
    bool canMerge(Action other) {
        TSelf otherChange = cast(TSelf) other;
        return (otherChange !is null && otherChange.getName() == this.getName());
    }
}

class NodeRootBaseSetAction : Action {
public:
    alias TSelf = typeof(this);
    Node node;
    bool origState;
    bool state;


    this(Node n, bool state) {
        this.node = n;
        this.origState = n.lockToRoot;
        this.state = state;

        n.lockToRoot = this.state;
    }

    /**
        Rollback
    */
    void rollback() {
        this.node.lockToRoot = origState;
    }

    /**
        Redo
    */
    void redo() {
        this.node.lockToRoot = state;
    }

    /**
        Describe the action
    */
    string describe() {
        if (origState) return _("%s locked to root node").format(node.name);
        else return _("%s unlocked from root node").format(node.name);
    }

    /**
        Describe the action
    */
    string describeUndo() {
        if (state) return _("%s locked to root node").format(node.name);
        else return _("%s unlocked from root node").format(node.name);
    }

    /**
        Gets name of this action
    */
    string getName() {
        return this.stringof;
    }
    
    /**
        Merge
    */
    bool merge(Action other) {
        if (this.canMerge(other)) {
            this.node.lockToRoot = !state;
            this.state = !state;
            return true;
        }
        return false;
    }

    /**
        Gets whether this node can merge with an other
    */
    bool canMerge(Action other) {
        TSelf otherChange = cast(TSelf) other;
        return otherChange && otherChange.node == this.node;
    }
}

/**
    Locks to root node
*/
void incLockToRootNode(Node n) {
    // Push action to stack
    incActionPush(new NodeRootBaseSetAction(
        n, 
        !n.lockToRoot
    ));
}